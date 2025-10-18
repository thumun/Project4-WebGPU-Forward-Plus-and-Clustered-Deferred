// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4<f32>,
    @location(0) pos: vec3<f32>,
    @location(1) nor: vec3<f32>,
    @location(2) uv: vec2<f32>
}

struct GBufferOutput
{
    @location(0) position: vec4<f32>,
    @location(1) normal: vec4<f32>,
    @location(2) albedo: vec4<f32>
}

@fragment
fn main(in: FragmentInput) -> GBufferOutput
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var output : GBufferOutput;
    output.position = vec4f(in.pos, 1.0);
    output.normal = vec4f(normalize(in.nor), 1.0);
    output.albedo = diffuseColor;

    return output;
}