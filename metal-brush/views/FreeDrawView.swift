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
    
    private lazy var defaultOffscreenColor = MTLClearColorMake(1, 1, 1, 1)
    private lazy var commandQueue = device?.makeCommandQueue()
    private lazy var defaultLibrary = device?.makeDefaultLibrary()
    private lazy var aspectRatio: Float = 1
    
    // Texture to render to and then sample from.
    private lazy var offscreenTexture: MTLTexture? = {
        let texDescriptor = MTLTextureDescriptor()
        texDescriptor.textureType = .type2D
        texDescriptor.width = Int(UIScreen.main.bounds.width)
        texDescriptor.height = Int(UIScreen.main.bounds.height)
        texDescriptor.pixelFormat = .bgra8Unorm
        texDescriptor.usage = [.renderTarget, .shaderRead]

        return device?.makeTexture(descriptor: texDescriptor)
    }()
    
    // Render pass descriptor to draw to the texture
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()

        descriptor.colorAttachments[0].texture = offscreenTexture;
        descriptor.colorAttachments[0].loadAction = .clear;
        descriptor.colorAttachments[0].clearColor = defaultOffscreenColor
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }()
    
    // A pipeline object to render to the offscreen texture.
    private lazy var offscreenRenderPipeline: MTLRenderPipelineState? = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Offscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "simpleVertexShader")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "simpleFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = offscreenTexture?.pixelFormat ?? .bgra8Unorm
        descriptor.vertexBuffers[Int(FreeDrawVertexInputIndexVertices.rawValue)].mutability = .immutable
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    // A pipeline object to render to the offscreen texture.
    private lazy var onscreenRenderPipeline: MTLRenderPipelineState? = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Onscreen Render Pipeline"
        descriptor.vertexFunction = defaultLibrary?.makeFunction(name: "textureVertexShader")
        descriptor.fragmentFunction =  defaultLibrary?.makeFunction(name: "textureFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
        descriptor.vertexBuffers[Int(FreeDrawVertexInputIndexVertices.rawValue)].mutability = .immutable
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    private lazy var triangleVertexBuffer: MTLBuffer? = {
        let triangleVertices: [FreeDrawSimpleVertex] =
        [
            .init(position: .init( 0.5,  -0.5), color: .init(1.0, 0.0, 0.0, 1.0)),
            .init(position: .init(-0.5,  -0.5), color: .init(0.0, 1.0, 0.0, 1.0)),
            .init(position: .init( 0.0,   0.5), color: .init(0.0, 0.0, 1.0, 0.0))
        ]
        return device?.makeBuffer(bytes: triangleVertices,
                                  length: triangleVertices.size(),
                                  options: .storageModeShared)
    }()
    
    private lazy var quadVertexBuffer: MTLBuffer? = {
        let quadVertices: [FreeDrawTextureVertex] =
        [
            .init(position: .init( 0.5, -0.5), texcoord: .init(1.0, 1.0)),
            .init(position: .init(-0.5, -0.5), texcoord: .init(0.0, 1.0)),
            .init(position: .init(-0.5,  0.5), texcoord: .init(0.0, 0.0)),
            
            .init(position: .init( 0.5, -0.5), texcoord: .init(1.0, 1.0)),
            .init(position: .init(-0.5,  0.5), texcoord: .init(0.0, 0.0)),
            .init(position: .init( 0.5,  0.5), texcoord: .init(1.0, 0.0))
        ]
        return device?.makeBuffer(bytes: quadVertices,
                                  length: quadVertices.size(),
                                  options: .storageModeShared)
    }()
    
    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        delegate = self
        isUserInteractionEnabled = true
        clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
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
        aspectRatio =  Float(size.height / size.width)
    }
    
    func draw(in view: MTKView) {
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

        renderEncoder.setVertexBuffer(triangleVertexBuffer, offset: 0,
                                      index: Int(FreeDrawVertexInputIndexVertices.rawValue))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
    }
    
    func renderOnscreen(with commandBuffer: MTLCommandBuffer, in view: MTKView) {
        guard let onscreenRenderPassDescriptor = view.currentRenderPassDescriptor else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: onscreenRenderPassDescriptor),
              let onscreenRenderPipeline else { return }
        renderEncoder.label = "Onscreen Render Pass";
        renderEncoder.setRenderPipelineState(onscreenRenderPipeline)

        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0,
                                      index: Int(FreeDrawVertexInputIndexVertices.rawValue))
        renderEncoder.setVertexBytes(&aspectRatio, length: MemoryLayout.size(ofValue: aspectRatio),
                                     index: Int(FreeDrawVertexInputIndexAspectRatio.rawValue))

        // Set the offscreen texture as the source texture.
        renderEncoder.setFragmentTexture(offscreenTexture, index: Int(FreeDrawTextureInputIndexColor.rawValue))

        // Draw quad with rendered texture.
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.endEncoding()
    }
}
