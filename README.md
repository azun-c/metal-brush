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
    
    ![Metal-circle WITHOUT](https://github.com/azun-c/metal-brush/assets/114891397/b10dcccd-541d-4053-9745-8f2e8d74d178)

  - Final result(Wit the alpha component processing):
    
    ![Metal-circle WITH](https://github.com/azun-c/metal-brush/assets/114891397/3ae69756-5386-4e6e-9387-28bf23f02435)


- And a curve line is just a series of `soft` dots that partially overlap when tapped and moved the finger on the screen.

### Rendering method: Offscreen rendering (aka Drawing to texture, Rendering to texture):

- The app uses a rendering method called [Offerscreen rendering](https://microsoft.github.io/Win2D/WinUI3/html/Offscreen.htm#:~:text=Apps%20occasionally%20need%20to%20draw,%22drawing%20to%20a%20texture%22.)

- Instead of rendering straight to the screen, it's storing the results in a texture. There are a couple of advantages of this method. Two on top advantages are:
  - The app will later need to access(read) the rendering data for storing purpose. However, the screen buffer data is a WRITE only buffer. We can only write the data for displaying to it, but cannot read the rendered data
  - When displaying to screen, there should be some `heavy` tasks because it's related to display, screens, I/O, etc. In the meantime, if we render directly to screen (buffer), including the preprocessing pixels(calcuations, translations, color transformations, blending, etc.), will result in a bad experience or an intermittent failure.
- So offscreen rendering manages a couple of offscreen buffers, all the computations are done and pixels are drawn on those buffers first, the final buffer holds the rendering data (which is similar to a texture, or an image). And the final step, we just need to write the exact pixels of the texture to the screen buffer. No more heavy tasks related to rendering pixels.
- ![Offscreen-rendering metal](https://github.com/azun-c/metal-brush/assets/114891397/d6200a08-bbb0-4a2e-9e92-8e88034b9497)
  - For example, with the current state, there is already a blue circle of the top left of screen, we tap in the middle of the screen to draw another red circle.
  - At that point, the offscreen buffer(also the offscreen texture) store `an image` of the current screen state. Then it we manages to render the red circle after a couple of rendering steps
  - At the end of the drawing frame(a drawing loop), we copy the final buffer's texture to the screen buffer for displaying
  - Begining a new drawing frame, the offscreen buffer now consists of 2 separate circles
  - When saving, we can read the offscreen texture's pixels the store as how we want

- In the app, we can see that it has 2 separate functions (`renderOffscreen(with:)` and `renderOnscreen(with:in:)`), which use 2 different pipeline instances for the drawing:
  - The result texture of `renderOffscreen(with:)` will be used as a texture sampler in `renderOnscreen(with:in:)`
  - `renderOffscreen(with:)` is supposed to do all the drawing tasks.
  - `renderOnscreen(with:in:)` just simply send the built texture to the renderer object

### Rendering pipeline: 
- Source: ([OpenGL_ES_2.0_Programming_Guide - Page 37/457](https://usermanual.wiki/Pdf/OpenGL20ES202020Programming20Guide.197713012/view))
  ![pipeline](https://github.com/azun-c/opengles-brush/assets/114891397/ea0619f8-c623-42ad-b38f-4dc3adaa3515)



- Let's dive into a bit. Let's focus on the stages with items marked as red number inside red circle. For easily imagination, I put sample data and result for each stage according to the OpenGL brush stroke app beside the stage items.
  - (1) Vertex Arrays/ Buffer Objects: In general, graphics libraries will work with simple geometries, called primities. They are points(formed by 1 vertex), lines(formed by 2 vertices), triangles(formed by 3 vertices). So our job is to translate our shapes into primities, which are in turn defined by a set of vertices.
    - Especially, in the app, when rendering a single circle, it first renders a square. Let's "simply" think that drawing a square is equal to drawing 2 opposite triangles: the first triangle has 3 vertices (v0, v1, v2), the second triangle has 3 vertices(v3, v4, v5), and v3 is exactly the same as v0, v4 is exactly the same as v2. (No spacing between the 2 triangles)
    - So the vertex array should be fetched with 6 vertices. (In reality, there are actually 18 vertices in this case :D, but not much different)
  - (2) Vertex Shader: This is a sub-routine, a small vital program, for processing every vertex from the vertex arrays. Its major responsibility is to map the position of each to the proper location in the drawing surface. And there may be some other processing if needed(such translations, scale, etc.)
    - The parameter is a vertex, passed from the vertex arrays.
  - (3) Primities Assembly: Based on the primity type (point, line, triangle), at this stage, the processed vertices, which are the outputs of stage 2, will be reassembled into a corresponding primities.
    - For example: If we're about to draw lines, then the `Primities Assembly` will be waiting until it receives 2 processed vertices in order to reassemble into a line. Similarly, for triangles, after `Vertex Shader` outputs 3 vertices, then the `Primities Assembly` will reassemble into a triangle.
    - In our case, the vertex array has 6 vertices (v0,.., v5), once the vertex shader finishes processing 3 vertices (v0, v1, v2), outputs as (v00, v11, v22) (into primities assembly buffer), the primities assembly will reassemble into a triangle, before passing to the next stage.
    - Note: This stage is a hidden stage. We have no control over it.
  - (4) Rasterization: At this stage, we have a primity(according to its vertices). To make a primity visible, we need to allocate colors to it by setting color to every single pixel belonging to the primity. However, we only have the pixel positions of very few vertices (i.e.: 3 for triangle), how can we determine if a pixel is inside or outside of the primity? This is the reason that the Rasterization comes into place. [Rasterization](https://www.khronos.org/opengl/wiki/Rasterization) is the process whereby each individual Primitive is broken down into discrete elements called Fragments. These fragments will be in turn fetched to the stage, called `Fragment Shader`.
    - Note: This stage is a hidden stage. We have no control over it.
 - (5) Texture Memory: This is where textures are stored, so that they can be used as samplers (in `Fragment Shader`), contributing to detemine the target color of a pixel.
 - (6) Fragment Shader:
   - ![fragment-texturing](https://github.com/azun-c/opengles-brush/assets/114891397/dc7ed3ee-5516-4740-820b-2010a1d18d6a)
   - Similar with Vertex Shader, this is also a small vital program. This will process each concrete fragment and allocate a suitable color to it. Depending on the needs, we can assign a same solid color to all the fragments or assign(and with processing) the color from a sampler (texture) like the above image.
   - In the app, we actualy maintain a list of ball pen textures, so that we will need to do the sampling from the suitable texture, to render a color (black or white) to each fragment
   - The similar process is applied for the rest of vertices(v3, v4, v5) for mapping the right side of the pen texture on screen.
- (7) [Framebuffer](https://learnopengl.com/Advanced-OpenGL/Framebuffers): A memory portion to store data of drawn primities. The data will be passed to the render buffer for displaying or later to store purpose.
- Conclusion: After preparing vertex data to fetch to vertex arrays, we just need to work with Vertex Shader and Fragement Shader generate the colorful pixels at the proper positions.

### High level explanation of brush stroke app: 
- Let's use the same example in the "Render Method" part above: The app already has a circle (in blue). Now, user taps at the center of the screen to draw another circle (in red). Let's review what happens behind the scence.
- ![framebuffers-in-details](https://github.com/azun-c/opengles-brush/assets/114891397/06879065-af02-4f64-96c0-a6ea6087a5ce)
- The app manages 2 Framebuffers(`m_offScreen` and `m_onScreen` - you may be confused because they're defined as different data types in source code, but don't mind)
  - As explained a bit above about offscreen rendering. `m_offScreen` is responsible for drawing stuff, `m_onScreen` is for displaying to screen.
- [Framebuffer objects are a collection of attachments.](https://www.khronos.org/opengl/wiki/Framebuffer_Object). In the app, each framebuffer contains only 1 attachment.
  - m_offScreen's attachment is a texture buffer. (Just imagine this is just an image data buffer - containing all drawn items as a single combined image)
  - m_onScreen's attachment is a [render buffer](https://www.khronos.org/opengl/wiki/Renderbuffer_Object). Renderbuffers are similar to Textures, however `they are optimized for use as render targets, while Textures may not be.`
- Also [A framebuffer is a "render target", a place OpenGL can draw pixels to. It is not a texture, but instead it contains textures (one or several)](https://www.cse.chalmers.se/edu/course/TDA362/tutorials/lab5.html), again, Framebuffers contain attachments, those attachments can be textures, renderbuffers, and other kinds.
  - So when executing any drawing commands, we need to target with a framebuffer (either `m_offScreen` or `m_onScreen`). When drawings happen, the attachments will get updated.
- Based on that, let's focus on the m_offScreen's texture and m_onScreen's renderbuffer states during a drawing frame:
  - (1) Before the new drawing happens, the m_offScreen's texture has the current state/image (which is the result of the previous drawing frame)
    - Note: The yellow background color just to mark this is a buffer, not a physical screen)
  - (2) Vertex Shader ([Normal.vert](https://github.com/azun-c/opengles-brush/blob/main/opengles-brush/shaders/Normal.vert)) determines the area of the new drawing
  - (3) Fragment Shader ([Normal.frag](https://github.com/azun-c/opengles-brush/blob/main/opengles-brush/shaders/Normal.frag)) allocates color for every pixel, based on the sampler (pen's texture)
  - (4) m_onScreen's Renderbuffer may have some previous drawings or blank (it doesn't matter, because the Renderbuffer will be filled soon)
    - Note: The green background color just to mark this is a buffer, not a physical screen)
  - (5) Vertex Shader ([Normal.vert](https://github.com/azun-c/opengles-brush/blob/main/opengles-brush/shaders/Normal.vert)) determines the area of the new drawing - the whole drawing surface
  - (6) Fragment Shader ([WhiteAsAlpha.frag](https://github.com/azun-c/opengles-brush/blob/main/opengles-brush/shaders/WhiteAsAlpha.frag)) allocates color for every pixel, based on the sampler (m_offScreen's texture - (3)) plus the transformation:
    - (White pixel -> target color pixel) & (Black pixel -> transparent pixel)
    - The m_onScreen's Renderbuffer is bound to the presenting surface, so anything on m_onScreen's Renderbuffer will display on the physical screen.
- [Program objects](https://www.khronos.org/opengl/wiki/GLSL_Object#Program_objects): are factors to execute every drawing commands. Each program should have the essential vertex shader and fragment shader. When drawing, the program will go through the `rendering pipeline` (as mentioned above). The app has 2 programs with the combinations of the 3 shaders: `Normal.vert`, `Normal.frag`, `WhiteAsAlpha.frag`.
- [Blending](https://learnopengl.com/Advanced-OpenGL/Blending)
  - This is an important technique to have the drawn items displayed as we want. If we don't use this, we won't able to render circles with rounded corner.
