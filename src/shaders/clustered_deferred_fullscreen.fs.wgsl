// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.


@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_gBuffer}) @binding(0) var posTex: texture_2d<f32>;
@group(${bindGroup_gBuffer}) @binding(1) var normTex: texture_2d<f32>;
@group(${bindGroup_gBuffer}) @binding(2) var albedoTex: texture_2d<f32>;

@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

fn getDepthSlice(zval: f32) -> u32 {
    return u32(log2(abs(zval) / camera.near)* f32(${clusterSizeZ}) / log2(camera.far / camera.near));
}

@fragment
fn main(@builtin(position) fragPos: vec4f) -> @location(0) vec4f
{
    let input = vec2i(fragPos.xy);
    let pos = textureLoad(posTex, input, 0).xyz;
    let albedo = textureLoad(albedoTex, input, 0);
    let norm = textureLoad(normTex, input, 0).xyz;

    let viewSpace = (camera.viewMat * vec4(pos, 1.0)).xyz;
    var clusterZVal  = getDepthSlice(viewSpace.z);

    var tileSizeInPx = vec2f(camera.screenX / f32(${clusterSizeX}), camera.screenY / f32(${clusterSizeY}));
    
    var clusters    = vec3<u32>(vec2<u32>( fragPos.xy / tileSizeInPx), clusterZVal);
    var clusterIdx = clusters.x +
                        ${clusterSizeX} * clusters.y +
                        (${clusterSizeX} * ${clusterSizeY}) * clusters.z;

    var totalLightContrib = vec3f(0, 0, 0);

    for (var lightIdx = 0u; lightIdx < clusterSet.clusters[clusterIdx].numLights; lightIdx++) {
        let lightIndex = clusterSet.clusters[clusterIdx].lightIndices[lightIdx];
        totalLightContrib += calculateLightContrib(lightSet.lights[lightIndex], pos, norm);
    }

    var finalColor = albedo.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}