//
//  FreeDrawView.swift
//  metal-brush
//
//  Created by azun on 26/02/2024.
//

import UIKit
import MetalKit

class FreeDrawView: MTKView {
    // FreeDrawProtocol
    var viewState: ViewStateProtocol?
    var triangles = Triangles()
    
    private lazy var defaultOffscreenColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    private lazy var commandQueue = device?.makeCommandQueue()
    private lazy var defaultLibrary = device?.makeDefaultLibrary()
    private lazy var viewportSize: SIMD2<Float> = .zero
    private var maxSampleCount: Int = 4
    
    // Texture to render to
    private lazy var offscreenTexture = createOffscreenTexture()
    
    // Pen Texture to sample from.
    private lazy var penTexture: MTLTexture? = loadPenTexture()
    
    // Render pass descriptor to draw to the texture
    private lazy var offscreenRenderPassDescriptor = createOffscreenRenderPass()
    
    // A pipeline object to render to the offscreen texture.
    private lazy var offscreenRenderPipeline = createOffscreenPipelineState()
    
    // A pipeline object to render to onscreen.
    private lazy var onscreenRenderPipeline = createOnscreenPipelineState()
    
    private lazy var textureSamplerState = createSamplerState()
    
    // A buffer for the rectangle, draw offscreen to onscreen
    private lazy var quadVertexBuffer = createOnscreenVertexBuffer()
    
    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        delegate = self
        isUserInteractionEnabled = true
        clearColor = defaultOffscreenColor
        backgroundColor = .clear
        autoResizeDrawable = true
        sampleCount = maxSampleCount
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - UIResponder
extension FreeDrawView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        viewState?.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        viewState?.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        viewState?.touchesEnded(touches, with: event)
    }
}

//MARK: - MTKViewDelegate
extension FreeDrawView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable to pass to the vertex shader.
        viewportSize.x = size.width.asFloat
        viewportSize.y = size.height.asFloat
    }
    
    func draw(in view: MTKView) {
        viewState?.onRender()
        
        guard let currentDrawable = view.currentDrawable,
                let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        
        commandBuffer.label = "Command Buffer"
        renderOffscreen(with: commandBuffer)
        renderOnscreen(with: commandBuffer, in: view)
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

//MARK: - FreeDrawProtocol
extension FreeDrawView: FreeDrawProtocol {
    var curveWidth: Float {
        let seconds = Calendar.current.component(.second, from: Date())
        return max(((seconds / 2) % 25).asFloat, 6)
    }
}

//MARK: - Private
private extension FreeDrawView {
    var drawingColor: SIMD4<Float> {
        // change color frequently
        let seconds = Calendar.current.component(.second, from: Date()) % 20
        if seconds > 15 {
            return UIColor.systemRed.asSIMD4
        }
        
        if seconds > 10 {
            return UIColor.systemGreen.asSIMD4
        }
        
        if seconds > 5 {
            return .init(1, 1, 0.6, 1)
        }
        
        return .init(0.6, 1, 0, 1)
    }
    
    func renderOffscreen(with commandBuffer: MTLCommandBuffer) {
        let triangleVertices = buildTriangleVertices()
        guard !triangleVertices.isEmpty else { return }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor),
              let offscreenRenderPipeline else { return }
        renderEncoder.label = "Offscreen Render Pass";
        renderEncoder.setRenderPipelineState(offscreenRenderPipeline)
        
        // Set the penTexture as the source texture.
        renderEncoder.setFragmentTexture(penTexture, index: FreeDrawTextureInputIndexColor.rawValue.asInt)
        
        // Set our sampler state so we can use it to sample the texture in the frag
        renderEncoder.setFragmentSamplerState(textureSamplerState,
                                              index: FreeDrawSamplerInputIndexSampler.rawValue.asInt)
        
        let triangleVertexBuffer = device?.makeBuffer(bytes: triangleVertices,
                                                      length: triangleVertices.size(),
                                                      options: .storageModeShared)
        renderEncoder.setVertexBuffer(triangleVertexBuffer, offset: 0,
                                      index: FreeDrawVertexInputIndexVertices.rawValue.asInt)
        var color = drawingColor
        renderEncoder.setVertexBytes(&color, length: MemoryLayout.size(ofValue: drawingColor),
                                     index: FreeDrawVertexInputIndexDrawColor.rawValue.asInt)
        // Draw polygon (a set of triangles) with pen texture.
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                     vertexCount: triangleVertices.count)
        
        renderEncoder.endEncoding()
    }
    
    func renderOnscreen(with commandBuffer: MTLCommandBuffer, in view: MTKView) {
        guard let onscreenRenderPassDescriptor = view.currentRenderPassDescriptor else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: onscreenRenderPassDescriptor),
              let onscreenRenderPipeline else { return }
        renderEncoder.label = "Onscreen Render Pass";
        renderEncoder.setRenderPipelineState(onscreenRenderPipeline)
        
        // Set the offscreenTexture as the source texture.
        renderEncoder.setFragmentTexture(offscreenTexture, index: FreeDrawTextureInputIndexColor.rawValue.asInt)
        
        // Set our sampler state so we can use it to sample the texture in the frag
        renderEncoder.setFragmentSamplerState(textureSamplerState,
                                              index: FreeDrawSamplerInputIndexSampler.rawValue.asInt)

        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0,
                                      index: FreeDrawVertexInputIndexVertices.rawValue.asInt)

        // Draw quad with rendered texture.
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.endEncoding()
    }
    
    func buildTriangleVertices() -> [FreeDrawTextureVertex] {
        guard triangles.m_triangles.count > 0 else { return [] }
        
        let triangleVerticesInViewportSpace = triangles.m_triangles.flatMap {
            $0.toVertexArray()
        }
        // inspired by: https://stackoverflow.com/a/66519925
        return triangleVerticesInViewportSpace.map {
            .init(position: metalCoordinate(for: $0.position),
                  texcoord: $0.texcoord)
        }
    }
    
    func metalCoordinate(for position: SIMD2<Float>) -> SIMD2<Float> {
        // Quote: To transform the position into Metal’s coordinates, the function needs the size of the viewport (in pixels) that the triangle is being drawn into ==> (position.x * scale, position.y * scale)
        // Ref: https://developer.apple.com/documentation/metal/using_a_render_pipeline_to_render_primitives
        let scale = contentScaleFactor.asFloat
        let inverseViewSize: SIMD2<Float> = .init(1.0 / viewportSize.x,
                                                  1.0 / viewportSize.y)
        let clipX = 2.0 * position.x * scale * inverseViewSize.x - 1.0
        let clipY = 2.0 * -position.y * scale * inverseViewSize.y + 1.0
        return .init(clipX, clipY)
    }
    
    func loadTexture(from name: String) -> MTLTexture? {
        guard let device else { return nil }
        let loader = MTKTextureLoader(device: device)
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return try? loader.newTexture(URL: url, options: [
            MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft,
            MTKTextureLoader.Option.SRGB: false
        ])
    }
    
    func loadPenTexture() -> MTLTexture? {
        let name: String
        
        if curveWidth > 24.0 {
            name = "FreeDrawPenGray_32"
        } else if curveWidth > 12.0 {
            name = "FreeDrawPenGray_16"
        } else if curveWidth > 6.0 {
            name = "FreeDrawPenGray-2_32"
        } else {
            name = "FreeDrawPenGray-2_16"
        }
        
        return loadTexture(from: name)
    }
    
    func createOffscreenTexture() -> MTLTexture? {
        let scaleFactor = contentScaleFactor
        let texDescriptor = MTLTextureDescriptor()
        texDescriptor.textureType = .type2D
        texDescriptor.width = (frame.size.width * scaleFactor).asInt
        texDescriptor.height = (frame.size.height * scaleFactor).asInt
        texDescriptor.pixelFormat = .bgra8Unorm
        texDescriptor.usage = [.renderTarget, .shaderRead]

        return device?.makeTexture(descriptor: texDescriptor)
    }
    
    func createOffscreenRenderPass() -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()

        descriptor.colorAttachments[0].texture = offscreenTexture;
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].clearColor = defaultOffscreenColor
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
    
    func createOffscreenPipelineState() -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Offscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "whiteAsAlphaVertex")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "whiteAsAlphaFragment")
        
        if let renderBufferAttachment = descriptor.colorAttachments[0] {
            renderBufferAttachment.pixelFormat = offscreenTexture?.pixelFormat ?? .bgra8Unorm
            
            renderBufferAttachment.isBlendingEnabled = true
            renderBufferAttachment.alphaBlendOperation = .max
            renderBufferAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            renderBufferAttachment.rgbBlendOperation = .add
            renderBufferAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        }
        
        descriptor.vertexBuffers[FreeDrawVertexInputIndexVertices.rawValue.asInt].mutability = .immutable
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func createOnscreenPipelineState() -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Onscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "normalVertex")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "normalFragment")
        if let renderBufferAttachment = descriptor.colorAttachments[0] {
            renderBufferAttachment.pixelFormat = self.colorPixelFormat
            renderBufferAttachment.isBlendingEnabled = true
            
            renderBufferAttachment.alphaBlendOperation = .add
            renderBufferAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            renderBufferAttachment.rgbBlendOperation = .add
            renderBufferAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        }
        descriptor.rasterSampleCount = maxSampleCount
        
        descriptor.vertexBuffers[FreeDrawVertexInputIndexVertices.rawValue.asInt].mutability = .immutable
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func createOnscreenVertexBuffer() -> MTLBuffer? {
        let quadVertices: [FreeDrawTextureVertex] =
        [
            .init(position: .init( 1.0, -1.0), texcoord: .init(1.0, 1.0)),
            .init(position: .init(-1.0, -1.0), texcoord: .init(0.0, 1.0)),
            .init(position: .init(-1.0,  1.0), texcoord: .init(0.0, 0.0)),
            
            .init(position: .init( 1.0, -1.0), texcoord: .init(1.0, 1.0)),
            .init(position: .init(-1.0,  1.0), texcoord: .init(0.0, 0.0)),
            .init(position: .init( 1.0,  1.0), texcoord: .init(1.0, 0.0))
        ]
        return device?.makeBuffer(bytes: quadVertices,
                                  length: quadVertices.size(),
                                  options: .storageModeShared)
    }
    
    func createSamplerState() -> MTLSamplerState? {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        return device?.makeSamplerState(descriptor: samplerDescriptor)
    }
}
