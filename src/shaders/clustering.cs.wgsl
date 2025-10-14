// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) var<read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(1) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(2) var<uniform> camera: CameraUniforms;

fn getBoundingBox() {

}

// could simplify this maybe?
fn sphereIntersectsAABB(center: vec3f, radius: f32, minB: vec3f, maxB: vec3f) -> bool {
    var distSq = 0.0;

    for (int i = 0; i < 3; i++) {
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


@compute @workgroup_size(camera.clusterSize)
fn computeMain(@builtin(global_invocation_id) index: vec3u) {
    let i = index.x;
    // total clusters = size of grid -> x * y * z
    if (i >= camera.clusterSize*camera.clusterSize*camera.clusterSize) {
        return;
    }

    int clusterIndx = index.x + index.y * camera.clusterSize + index.z * (camera.clusterSize * camera.clusterSize);

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).

// oh wait is this px space?
    var minScreenBounds = vec2f(index.x * camera.screenX / camera.clusterSize, 
                             index.y * camera.screenY  / camera.clusterSize);

    var maxScreenBounds = vec2f((index.x + 1) * camera.screenX / camera.clusterSize, 
                             (index.y + 1) * camera.screenY  / camera.clusterSize);

//     - Calculate the depth bounds for this cluster in Z (near and far planes).

    var nearBounds;
    var farBounds;

//     - Convert these screen and depth bounds into view-space coordinates.
    
    // convert from px to screen
    // (px/width) * 2 - 1
    // 1 - (py/height)* 2

    // P *= Uw (to unhomogenized)

    // Proj_Mat^-1 * P (to camera)

//     - Store the computed bounding box (AABB) for the cluster.

    var bounds;

    clusterSet[clusterIndex].minBounds = bounds.minBounds;
    clusterSet[clusterIndex].maxBounds = bounds.maxBounds;

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

    int lightCount = 0; 

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

    for (int i = 0; i < LightSet.numLights; i++) 
    {

        // !! may need to convert light to be in cam space since above puts everything in cam space (min/max bounds)
        // mult w/ view mat to do world -> cam

        if (sphereIntersectsAABB(LightSet.lights[i].pos, ${lightRadius}, clusterSet[clusterIndx].minBounds, clusterSet[clusterIndx].maxBounds))
        {
            lightCount++;

            if (lightCount >= $(maxLights)) {
                break;
            }
            else {
                clusterSet[clusterIndx].lightIndices.add(LightSet.lights[i]);
            }
        }
    }

//     - Store the number of lights assigned to this cluster.
    clusterSet[clusterIndx].numLights = lightCount;
}