WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Neha Thumu
  * [LinkedIn](https://www.linkedin.com/in/neha-thumu/)
* Tested on: Windows 11 Pro, i9-13900H @ 2.60GHz 32GB, Nvidia GeForce RTX 4070

![clustereddef5k](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/clustereddeferred5k.gif?raw=true)

## Live Demo

[Link to run in your browser!](https://thumun.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

### Control Scheme 
You can navigate the scene by using WASD on your keyboard. This will allow you to move forward, left, right, and backward (mapped accordingly). You can also rotate the camera by holding the mouse down and rotating the mouse. 

At the top right of the screen, there is a control panel where you can adjust the number of lights in the scene along with the rendering method being utilized.

## Demo Video/GIF

[Link to see demo!](TODO) -- update!!

## Project Details
### Naive/Forward Method 
This method of rendering is where for each fragment, you look at all of the lights in the scene in order to compute the lighting and thereby the color of that fragment. This can be particularly expensive when there are many lights in the scene as well as rather inefficient. For example, if there is a light that would not reach/affect a fragment in any way, there is no need to even consider it. Which is how Forward+ can be used as an optimization! 

![naive](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/naive.gif?raw=true)

### Forward+ Method
Forward+ takes the Naive method and adds a small but significant optimization: adding clusters. Clusters are split portions of the screen that hold information about which lights affect the pixels within the cluster. So, rather than checking every light in the scene while rendering, we simply look at which cluster the fragment is in and refer to the lights that affect that cluster-which is a lot more efficient! 

Clusters are frustrums that correspond to tiles on our screen. In that manner, they are reliant on the camera view and are recomputed if there are that changes. The clusters themselves are computed with the help of a compute shader. Prior to the shader, we first choose how to divvy up the screen. In this implementation, I chose 16 in the x direction, 9 in the y direction, and 24 in the z direction as this is in line with the aspect ratio that I am working with. Then, in the shader we calculate the screen-space bounds for the cluster first and then the depth bounds via the near/far planes of the camera. We then want to get the view-space coordinates and compute the min/max bounds of the cluster.

The min/max bounds are necessary in assigning the lights to the clusters. We check if each light intersects with the cluster's bounds and if so, we add it to the cluster's set of lights-as long as we have not hit the max number of lights a cluster can have. We then use a similar fragment shader as the naive method but utilize clusters rather than looping through all of the lights.

![fwdplus](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/forwardplus.gif?raw=true)

### Clustered Deferred Method 
The Clustered Deferred method further optimizes the Forward+ method by writing our geometry information to textures in various passes and then sampling those textures in the fragment shader. In this implementation, there is only two passes in total. In the initial pass, we initialize these textures which are referred to as G-Buffers. We create three such buffers for position, normal, and albedo (aka the base colors). We use the same vertex shader process as before to acquire our fragment data then we have a new fragment shader thar takes this data and stores it in our various G-Buffers. 

In the second pass, we sample these buffers (that are textures) in order to render the scene. As this is working from Forward+, we use the same cluster process from before to ensure we don't loop through all of the lights in our scene. 

![clustereddef](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/clustereddeferred.gif?raw=true)

## Performance Analysis

FPS  |  Milliseconds per Frame
:-------------------------:|:-------------------------:
![fps](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/fps.png?raw=true) |  ![ms](https://github.com/thumun/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/blob/main/img/msperframe.png?raw=true) |

As a note, the millisecond tracker was not working for me so I calculated the second chart by using the FPS.

The charts indicate that the Clustered Deferred method is faster than the Forward Plus method and this is especially visible with high numbers of lights. The naive method, as expected, is considerably slower than the other two which is very visible at the higher light numbers. In general, the Naive method has a clear trend where after the lights get to around 1000 the frame rate drops significantly and stays that way. For the Forward Plus, the trend is much more gradual however by 3500-4000 lights it somewhat plateaus. For the Clustered Deffered, it is generally pretty consistent (and very fast) except for the final few datapoints. It is interesting to note that for the small amounts of lights (100 and 1000) the Clustered Deferred has a lower speed compared to higher numbers.

Clustered Deferred is generally better than Forward Plus in this situation due to its efficiency and speed. The precomputations that the Clustered Deferred method provides (in having the geometry represented as textures that we can sample) significantly speeds up the process in the final fragment shader. Expanding beyond this project, Clustered Deferred would most likely excel over Forward Plus for situations where they is more complex geometry and more lights in the scene that needs to be processed. As, the lighting would only be computed only once per each fragment in the scene. However, Forward Plus may excel in situations where the buffers in Clustered are not necessary in making things faster. This would be in simpler scenes (where there are not that many lights for example).

In terms of trade-offs, for Clustered Deffered, although it provides a way to process more complex scenes easily and avoids overdraw, there is a significantly higher cost in supporting transparency and MSAA. There is also more bandwith for this method than for Forward Plus. The trade-offs for Forward Plus are essentially the opposite of clustered, although it can handle transparency and MSAA and has a lower bandwith, it has a worse performance for more complex scenes. 

For potential avenues of optimization, one big factor would be to be more cautious when creating structs/buffers that will be copied over to the GPU. I think I definitely had data that I either did not use or could have been a constant but was instead passed as a buffer. I could also rewrite some of the helper functions to get rid of unnecessary for loops- for example, I think my SphereIntersectAABB function did not need to have a for loop and could be simplified.

## Resources Utilized 

- [Forward+ Process](https://www.aortiz.me/2018/12/21/CG.html#part-2)
- [Clustered Deferred Process](https://webgpu.github.io/webgpu-samples/?sample=deferredRendering#fragmentWriteGBuffers.wgsl)
- [WebGPU offset calculator](https://webgpufundamentals.org/webgpu/lessons/resources/wgsl-offset-computer.html#)

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
