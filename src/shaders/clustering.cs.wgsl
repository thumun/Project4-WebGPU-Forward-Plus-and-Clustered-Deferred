// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) var<read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(1) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(2) var<uniform> camera: CameraUniforms;

fn screen2View(screen: vec4f) -> vec4f {
    //Convert to NDC
    var texCoord = vec2f(screen[0] / camera.screenX, screen[1] / camera.screenY);

    //Convert to clipSpace
    vec4 clip = vec4(vec2(texCoord[0], 1.0 - texCoord[1])* 2.0 - 1.0, screen[2], screen[3]);

    //View space transform
    vec4 view = camera.invProjMat * clip;

    //Perspective projection
    view = view / view[3];

    return view;
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


@compute @workgroup_size(16, 16)
fn computeMain(@builtin(global_invocation_id) index: vec3u) {
    let i = index.x;
    // total clusters = size of grid -> x * y * z
    if (i >= camera.clusterSizeX*camera.clusterSizeY*camera.clusterSizeZ) {
        return;
    }

    int clusterIndx = index.x + index.y * camera.clusterSizeX + index.z * (camera.clusterSizeX * camera.clusterSizeY);

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).

// oh wait is this px space?

    var tileSizePx = vec3f(camera.clusterSizeX, camera.clusterSizeY, camera.clusterSizeZ);

    var minScreenBounds = vec4f(vec2f(index.x * tileSizePx, 
                             index.y * tileSizePx), -1.0, 1.0);

    var maxScreenBounds = vec4f(vec2f((index.x + 1) * tileSizePx, 
                             (index.y + 1) * tileSizePx), -1.0, 1.0);

//     - Calculate the depth bounds for this cluster in Z (near and far planes).

    var nearBounds = -1.0 * camera.near * pow(camera.far/camera.near, index.z/camera.clusterSizeZ);
    var farBounds = -1.0 * camera.near * pow(camera.far/camera.near, index.z/camera.clusterSizeZ);

//     - Convert these screen and depth bounds into view-space coordinates.

    var minPointView = screen2View(minScreenBounds).xyz;
    var maxPointView = screen2View(maxScreenBounds).xyz;

//     - Store the computed bounding box (AABB) for the cluster.

    vec3 minPointNear = minPointView * nearBounds;
    vec3 minPointFar  = minPointView * farBounds;
    vec3 maxPointNear = maxPointView * nearBounds;
    vec3 maxPointFar  = maxPointView * farBounds;

    vec3 minPointAABB = min(min(minPointNear, minPointFar), min(maxPointNear, maxPointFar));
    vec3 maxPointAABB = max(max(minPointNear, minPointFar), max(maxPointNear, maxPointFar));

    clusterSet[clusterIndex].minBounds = minPointAABB;
    clusterSet[clusterIndex].maxBounds = maxPointAABB;

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