// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

fn lineIntersectionToZPlane(a: vec3f, b: vec3f, zDistance: f32) -> vec3f {
    var normal = vec3(0.0, 0.0, 1.0);
    var ab =  b - a;
    var t = (zDistance - dot(normal, a)) / dot(normal, ab);
    return a + t * ab;
}

fn screen2View(screen: vec4f) -> vec4f {
    var texCoord = vec2f(screen[0] / camera.screenX, screen[1] / camera.screenY);

    var clip = vec4f(vec2f(texCoord[0] * 2.0 - 1.0, texCoord[1] * 2.0 - 1.0), screen[2], screen[3]);
    clip.y = -clip.y;
    var view = camera.invProjMat * clip;

    return view / view.w;

}

fn sphereIntersectsAABB(center: vec3f, radius: f32, minB: vec3f, maxB: vec3f) -> bool {
    var distSq = 0.0;

    for (var i = 0; i < 3; i++) {
        if (center[i] < minB[i]) {
            let d = minB[i] - center[i];
            distSq += d * d;
        } else if (center[i] > maxB[i]) {
            let d = center[i] - maxB[i];
            distSq += d * d;
        }
    }

    return distSq <= radius * radius;
}


@compute @workgroup_size(${clusterWorkGroupSize}, ${clusterWorkGroupSize}, ${clusterWorkGroupSize})
fn computeMain(@builtin(global_invocation_id) index: vec3u) {
   
    if ( (index.x >= ${clusterSizeX}) || (index.y >= ${clusterSizeY}) || (index.z >= ${clusterSizeZ})) {
        return;
    }

    var clusterIndx = index.x + index.y * ${clusterSizeX} + index.z * (${clusterSizeX} * ${clusterSizeY});

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).

    var tileSizeInPx = vec2f(camera.screenX / ${clusterSizeX}, camera.screenY / ${clusterSizeY});

    var minScreenBounds = vec4f(vec2f(f32(index.x) * tileSizeInPx.x, 
                             f32(index.y) * tileSizeInPx.y), -1.0, 1.0);

    var maxScreenBounds = vec4f(vec2f(f32((index.x + 1)) * tileSizeInPx.x, 
                             f32((index.y + 1)) * tileSizeInPx.y), -1.0, 1.0);

//     - Calculate the depth bounds for this cluster in Z (near and far planes).

    var nearBounds = -1.0 * camera.near * pow(camera.far/camera.near, f32(index.z)/f32(${clusterSizeZ}));
    var farBounds =  -1.0 * camera.near * pow(camera.far/camera.near, f32((index.z+1))/f32(${clusterSizeZ}));

//     - Convert these screen and depth bounds into view-space coordinates.

    var minPointView = screen2View(minScreenBounds).xyz;
    var maxPointView = screen2View(maxScreenBounds).xyz;

//     - Store the computed bounding box (AABB) for the cluster.

    var eyePos = vec3f(0.0f);
    var minPointNear = lineIntersectionToZPlane(eyePos, minPointView, nearBounds);
    var minPointFar  = lineIntersectionToZPlane(eyePos, minPointView, farBounds);
    var maxPointNear = lineIntersectionToZPlane(eyePos, maxPointView, nearBounds);
    var maxPointFar  = lineIntersectionToZPlane(eyePos, maxPointView, farBounds);

    var minPointAABB = min(min(minPointNear, minPointFar), min(maxPointNear, maxPointFar));
    var maxPointAABB = max(max(minPointNear, minPointFar), max(maxPointNear, maxPointFar));

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

    var lightCount = 0u; 

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

    for (var i = 0u; i < lightSet.numLights; i++) 
    {

        // !! may need to convert light to be in cam space since above puts everything in cam space (min/max bounds)
        // mult w/ view mat to do world -> cam
        var viewPos = camera.viewMat * vec4f(lightSet.lights[i].pos, 1.0);

        if (sphereIntersectsAABB(viewPos.xyz, f32(${lightRadius}), minPointAABB, maxPointAABB))
        {
            lightCount++;
            clusterSet.clusters[clusterIndx].lightIndices[lightCount - 1u] = i;

            if (lightCount >= ${maxLights}) {
                break;
            }
        }
    }

//     - Store the number of lights assigned to this cluster.
    clusterSet.clusters[clusterIndx].numLights = lightCount;
}