import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    gBufferBindGroupLayout: GPUBindGroupLayout;
    gBufferBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    positionTexture: GPUTexture;
    positionTextureView: GPUTextureView;

    normalTexture: GPUTexture;
    normalTextureView: GPUTextureView;

    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;

    gBufferPipeline: GPURenderPipeline;
    fullscreenPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
        
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                { // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // cluserSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }
            ]
        });

        this.positionTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            format: 'rgba16float',
        });
        this.positionTextureView = this.positionTexture.createView();

        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            format: 'rgba16float',
        });
        this.normalTextureView = this.normalTexture.createView();

        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            format: renderer.canvasFormat,
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.depthTextureView = this.depthTexture.createView();

        this.gBufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "gBuffer bind group layout",
            entries: [
                { // pos
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { }
                },
                { // norm
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { }
                },
                { // albedo
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { }
                }
            ]
        });

        this.gBufferBindGroup = renderer.device.createBindGroup({
            label: "gbuffer bind group",
            layout: this.gBufferBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.positionTextureView,
                },
                {
                    binding: 1,
                    resource: this.normalTextureView,
                },
                {
                    binding: 2,
                    resource: this.albedoTextureView,
                }
            ]
        });

        // GBuffer pipeline
        this.gBufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "G-Buffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {
                        format: "rgba16float", // pos
                    },
                    {                        
                        format: "rgba16float", // norm
                    },
                    {
                        format: renderer.canvasFormat, // albedo
                    }
                ]
            }
        });

        // Fullscreen pipeline
        this.fullscreenPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "fullscreen pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    undefined,
                    undefined,
                    this.gBufferBindGroupLayout // since this is 3 in consts
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        const encoderCompute = renderer.device.createCommandEncoder();        
        this.lights.doLightClustering(encoderCompute);
        renderer.device.queue.submit([encoderCompute.finish()]);

        const encoder = renderer.device.createCommandEncoder();

        // - run the G-buffer pass, outputting position, albedo, and normals
        const gBufferRenderPass = encoder.beginRenderPass({
            label: "gbuffer render pass",
            colorAttachments: [
                {
                view: this.positionTextureView,

                clearValue: [0, 0, 0, 0],
                loadOp: 'clear',
                storeOp: 'store',
                },
                {
                view: this.normalTextureView,

                clearValue: [0, 0, 0, 0],
                loadOp: 'clear',
                storeOp: 'store',
                },
                {
                view: this.albedoTextureView,

                clearValue: [0, 0, 0, 0],
                loadOp: 'clear',
                storeOp: 'store',
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,

                depthClearValue: 1.0,
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
            },
        });

        gBufferRenderPass.setPipeline(this.gBufferPipeline);
        gBufferRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            gBufferRenderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            gBufferRenderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gBufferRenderPass.setVertexBuffer(0, primitive.vertexBuffer);
            gBufferRenderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gBufferRenderPass.drawIndexed(primitive.numIndices);
        });

        gBufferRenderPass.end();

        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        const fullscreenRenderPass = encoder.beginRenderPass({
            label: "fullscreen render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        fullscreenRenderPass.setPipeline(this.fullscreenPipeline);
        fullscreenRenderPass.setBindGroup(shaders.constants.bindGroup_gBuffer, this.gBufferBindGroup);
        fullscreenRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        fullscreenRenderPass.draw(6, 1);

        fullscreenRenderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
