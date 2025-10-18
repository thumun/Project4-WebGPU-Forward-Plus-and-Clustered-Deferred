WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Neha Thumu
  * [LinkedIn](https://www.linkedin.com/in/neha-thumu/)
* Tested on: Windows 11 Pro, i9-13900H @ 2.60GHz 32GB, Nvidia GeForce RTX 4070

### Live Demo

[![](img/thumb.png)](https://thumun.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

### Demo Video/GIF

[![](img/video.mp4)](TODO)

### Project Details
## Naive/Forward Method 
This method of rendering is where for each fragment, you look at all of the lights in the scene in order to compute the lighting and thereby the color of that fragment. This can be particularly expensive when there are many lights in the scene as well as rather inefficient. For example, if there is a light that would not reach/affect a fragment in any way, there is no need to even consider it. Which is how Forward+ can be used as an optimization! 

## Forward+ Method
Forward+ takes the Naive method and adds a small but significant adjustment: adding clusters. Clusters are split portions of the screen that hold information about which lights affect the pixels within the cluster. These clusters reliant on the camera view and are recomputed if there are ant changes. The process of creating clusters is quite straighforward: 

First, to make the cluster grid, the camera view/screen is divvied up based on how many clusters you want to have. For this implementation, I chose 16 in the x direction, 9 in the y direction, and 24 in the z direction as this is in line with the aspect ratio that I am working with. In order to determine which lights affect which clusters, these clusters need to be frustrums.


## Clustered Deferred Method 
//

### Performance Analysis


### Resources Utilized 

- [Forward+ Process](https://www.aortiz.me/2018/12/21/CG.html#part-2)
- [Clustered Deferred Process](https://webgpu.github.io/webgpu-samples/?sample=deferredRendering#fragmentWriteGBuffers.wgsl)
- [WebGPU offset calculator](https://webgpufundamentals.org/webgpu/lessons/resources/wgsl-offset-computer.html#)

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
