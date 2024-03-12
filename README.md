# metal-brush

A simple standalone Metal app for brush stroke

---
### How does the current Metal app draw a dot (circle) with a specific color?

- For example:

  https://github.com/azun-c/metal-brush/assets/114891397/5240989b-c723-4a18-a3a7-c5fab8c6c730



- First, when tapped, depends on how big the brush size is, the app will determine a square at the tapped location.
  - Note: at this time, the square has not been painted with a color yet

  ![Metal-circle](https://github.com/azun-c/metal-brush/assets/114891397/b5d85af2-4089-4027-a049-64bc013391b7)


- Then, with the sampler texture( or image) based on the size (textures are located [here](https://github.com/azun-c/metal-brush/tree/main/metal-brush/textures)), the color of a every pixel will be filled with the drawing color, also applied with the tranformation of alpha component.
  - Note that: the texture has only 2 colors: white at the center and black at edges and borders. By mapping:
    - White pixel -> keep the alpha component of the drawing color
    - Black pixel -> adjust the alpha component of the drawing color to make it transparent
  
  - Without the alpha component processing:
    
    ![Metal-circle without](https://github.com/azun-c/metal-brush/assets/114891397/8e448ebe-0c67-48c2-8b4f-7f0f0910e804)


  - Final result(Wit the alpha component processing):
    
    ![Metal-circle with](https://github.com/azun-c/metal-brush/assets/114891397/37756cbc-2d06-47e1-8bf2-aa29985edb02)



- And a curve line is just a series of `soft` dots that partially overlap when tapped and moved the finger on the screen.

### Rendering method: Offscreen rendering (aka Drawing to texture, Rendering to texture):

- The app uses a rendering method called [Offerscreen rendering](https://microsoft.github.io/Win2D/WinUI3/html/Offscreen.htm#:~:text=Apps%20occasionally%20need%20to%20draw,%22drawing%20to%20a%20texture%22.)

- Instead of rendering straight to the screen, it's storing the results in a texture. There are a couple of advantages of this method. Two on top advantages are:
  - The app will later need to access(read) the rendering data for storing purpose. However, the screen buffer data is a WRITE only buffer. We can only write the data for displaying to it, but cannot read the rendered data
  - When displaying to screen, there should be some `heavy` tasks because it's related to display, screens, I/O, etc. In the meantime, if we render directly to screen (buffer), including the preprocessing pixels(calcuations, translations, color transformations, blending, etc.), will result in a bad experience or an intermittent failure.
- So offscreen rendering manages a couple of offscreen buffers, all the computations are done and pixels are drawn on those buffers first, the final buffer holds the rendering data (which is similar to a texture, or an image). And the final step, we just need to write the exact pixels of the texture to the screen buffer. No more heavy tasks related to rendering pixels.
- ![Offscreen-rendering metal](https://github.com/azun-c/metal-brush/assets/114891397/a4a2e6ec-5f6d-4af4-b72c-9a27dfe38a53)
  - For example, with the current state, there is already a blue circle of the top left of screen, we tap in the middle of the screen to draw another red circle.
  - At that point, the offscreen buffer(also the offscreen texture) stores `an image` of the current screen state. Then it manages to render the red circle after a couple of rendering steps
  - At the end of the drawing frame(a drawing loop), it copies the final buffer's texture to the screen buffer for displaying
  - Begining a new drawing frame, the offscreen buffer now consists of 2 separate circles
  - When saving, we can read the offscreen texture's pixels the store as how we want

- In the app, we can see that it has 2 separate functions (`renderOffscreen(with:)` and `renderOnscreen(with:in:)`), which use 2 different pipeline instances for the drawing:
  - The result texture of `renderOffscreen(with:)` will be used as a texture sampler in `renderOnscreen(with:in:)`
  - `renderOffscreen(with:)` is supposed to do all the drawing tasks.
  - `renderOnscreen(with:in:)` just simply sends the composed texture to the renderer object for displaying

### Rendering pipeline: 
- [![Rendering-pipeline](https://github.com/azun-c/metal-brush/assets/114891397/d1fef164-835d-4b6f-bf4d-e01f43255762)](https://www.haroldserrano.com/blog/before-using-metal-computer-graphics-basics#the-rendering-pipeline)

- The idea is almost the same as OpenGL ES. Please refer [here](https://www.haroldserrano.com/blog/before-using-metal-computer-graphics-basics#the-rendering-pipeline) and [here](https://www.haroldserrano.com/blog/before-using-metal-computer-graphics-basics#the-rendering-pipeline)

### High level explanation of brush stroke app: 
- Let's use the same example in the "Render Method" part above: The app already has a circle (in blue). Now, user taps at the center of the screen to draw another circle (in red). Let's review what happens behind the scence.
- ![Metal-in-details](https://github.com/azun-c/metal-brush/assets/114891397/30669e7c-b11a-43b7-af1c-858133eb4546)
- The process is similar to the OpenGL ES app, documented [here](https://github.com/azun-c/opengles-brush?tab=readme-ov-file#high-level-explanation-of-brush-stroke-app), with some adjustments:
  - The framebuffers are replaced by [Render Command Encoder](https://developer.apple.com/documentation/metal/mtlrendercommandencoder)
  - The programs are replaced by [Render Pipeline State](https://developer.apple.com/documentation/metal/mtlrenderpipelinestate)
    - There is an enhancement: the pen texture sampling and alpha processing are combined into 1 single pipeline (`offscreenRenderPipeline`). The other pipeline just copies the composed texture to the render object for displaying.
    - The fragement shader has an additional enhancement to reduce `halo`(dust) around the circle. (easier to see on devices)
      - ![issue](https://github.com/azun-c/metal-brush/assets/114891397/003cbf2f-d974-40fc-b73d-06793137e949) -> ![fix](https://github.com/azun-c/metal-brush/assets/114891397/086e2584-9c2f-4974-b0a0-5b335dc3081d)

### A bit more about Metal/MetalKit
- Basic:
  - [Using a Render Pipeline to Render Primitives](https://developer.apple.com/documentation/metal/using_a_render_pipeline_to_render_primitives)
  - [Using Metal to Draw a View’s Contents](https://developer.apple.com/documentation/metal/using_metal_to_draw_a_view_s_contents)
- More ebooks can be found in this [issue](https://cimtops.atlassian.net/browse/IRDPM-14556)
- [Convert screen coordinates to Metal's Normalized Device Coordinates](https://stackoverflow.com/a/66519925)
