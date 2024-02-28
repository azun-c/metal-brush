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
    var curveWidth: Float = 25
    
    private lazy var defaultOffscreenColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    private lazy var commandQueue = device?.makeCommandQueue()
    private lazy var defaultLibrary = device?.makeDefaultLibrary()
    private lazy var drawingColor = SIMD4<Float>(1.0, 0.0, 1.0, 1.0)
    private lazy var viewportSize: vector_uint2 = .zero
    
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
    
    // A buffer for the rectangle, draw offscreen to onscreen
    private lazy var quadVertexBuffer = createOnscreenVertexBuffer()
    
    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        delegate = self
        isUserInteractionEnabled = true
        clearColor = MTLClearColorMake(0 , 0, 0, 0)
        backgroundColor = .clear
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
        viewportSize.x = size.width.asUInt32
        viewportSize.y = size.height.asUInt32
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
    
}

//MARK: - Private
private extension FreeDrawView {
    func renderOffscreen(with commandBuffer: MTLCommandBuffer) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor),
              let offscreenRenderPipeline else { return }
        renderEncoder.label = "Offscreen Render Pass";
        renderEncoder.setRenderPipelineState(offscreenRenderPipeline)
        
        // Set the penTexture as the source texture.
        renderEncoder.setFragmentTexture(penTexture, index: FreeDrawTextureInputIndexColor.rawValue.asInt)
        
        let triangleVertices = buildTriangleVertices()
        if !triangleVertices.isEmpty {
            let triangleVertexBuffer = device?.makeBuffer(bytes: triangleVertices,
                                                          length: triangleVertices.size(),
                                                          options: .storageModeShared)
            renderEncoder.setVertexBuffer(triangleVertexBuffer, offset: 0,
                                          index: FreeDrawVertexInputIndexVertices.rawValue.asInt)
            // Draw polygon (a set of triangles) with pen texture.
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                         vertexCount: triangleVertices.count)
        }
        
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

        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0,
                                      index: FreeDrawVertexInputIndexVertices.rawValue.asInt)
        renderEncoder.setVertexBytes(&drawingColor, length: MemoryLayout.size(ofValue: drawingColor),
                                     index: FreeDrawVertexInputIndexDrawColor.rawValue.asInt)

        // Draw quad with rendered texture.
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.endEncoding()
    }
    
    func buildTriangleVertices() -> [FreeDrawTextureVertex] {
        guard triangles.m_triangles.count > 0 else { return [] }
        return buildTriangleVerticesWithOpenGLSpacePosition()
    }
    
    func buildTriangleVerticesWithOpenGLSpacePosition() -> [FreeDrawTextureVertex] {
        let halfWidth = Float(viewportSize.x / 2)
        let halfHeight = Float(viewportSize.y / 2)
        let scale = simd_float1(UIScreen.main.scale)
        
        let triangleVerticesWithOpenGLSpace: [FreeDrawTextureVertex] = triangles.m_triangles.flatMap {
            Array(arrayLiteral:
                    FreeDrawTextureVertex(position: .init($0.p1.position.x, $0.p1.position.y),
                                          texcoord: .init($0.p1.texPos.x, $0.p1.texPos.y)),
                  FreeDrawTextureVertex(position: .init($0.p2.position.x, $0.p2.position.y),
                                        texcoord: .init($0.p2.texPos.x, $0.p2.texPos.y)),
                  FreeDrawTextureVertex(position: .init($0.p3.position.x, $0.p3.position.y),
                                        texcoord: .init($0.p3.texPos.x, $0.p3.texPos.y))
            )
        }
        
        let triangleVerticesWithMetalPixelSpace = triangleVerticesWithOpenGLSpace.map {
            let transformedX = $0.position.x * scale - halfWidth
            let x = min(max(-halfWidth, transformedX), halfWidth)
            
            let transformedY = -($0.position.y) * scale + halfHeight
            let y = min(max(-halfHeight, transformedY), halfHeight)
            return FreeDrawTextureVertex(position: .init(x, y),
                                         texcoord: .init($0.texcoord.x,
                                                         $0.texcoord.y))
        }
        
        let projection = simd_float4x4([
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ])
        
        let modelView = simd_float4x4([
            [1.0/halfWidth, 0, 0, 0],
            [0, 1.0/halfHeight, 0, 0],
            [0, 0, 1, 0],
            [-1, 1, 0, 1]
        ])
        
        let triangleVertices = triangleVerticesWithMetalPixelSpace.map {
            let transformedVertex = projection * modelView * simd_float4($0.position.x, $0.position.y, 0, 0)
            let vertex = simd_float2(transformedVertex.x, transformedVertex.y)
            return FreeDrawTextureVertex(position: vertex, texcoord: $0.texcoord)
        }
        return triangleVertices
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
        let texDescriptor = MTLTextureDescriptor()
        texDescriptor.textureType = .type2D
        texDescriptor.width = UIScreen.main.bounds.width.asInt
        texDescriptor.height = UIScreen.main.bounds.height.asInt
        texDescriptor.pixelFormat = .bgra8Unorm
        texDescriptor.usage = [.renderTarget, .shaderRead]

        return device?.makeTexture(descriptor: texDescriptor)
    }
    
    func createOffscreenRenderPass() -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()

        descriptor.colorAttachments[0].texture = offscreenTexture;
        descriptor.colorAttachments[0].loadAction = .load;
        descriptor.colorAttachments[0].clearColor = defaultOffscreenColor
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
    
    func createOffscreenPipelineState() -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Offscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "normalVertex")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "normalFragment")
        
        if let renderBufferAttachment = descriptor.colorAttachments[0] {
            renderBufferAttachment.pixelFormat = offscreenTexture?.pixelFormat ?? .bgra8Unorm
            
            renderBufferAttachment.isBlendingEnabled = true
            renderBufferAttachment.alphaBlendOperation = .max
            renderBufferAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            renderBufferAttachment.rgbBlendOperation = .max
            renderBufferAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderBufferAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        }
        
        descriptor.vertexBuffers[FreeDrawVertexInputIndexVertices.rawValue.asInt].mutability = .immutable
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func createOnscreenPipelineState() -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Onscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "whiteAsAlphaVertex")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "whiteAsAlphaFragment")
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
}
