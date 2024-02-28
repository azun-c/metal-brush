//
//  Triangle+Extensions.swift
//  metal-brush
//
//  Created by azun on 28/02/2024.
//

import Foundation

extension Triangle {
    func toVertexArray() -> [FreeDrawTextureVertex] {
        Array(arrayLiteral:
                FreeDrawTextureVertex(position: .init(from: p1.position), texcoord: .init(from: p1.texPos)),
                FreeDrawTextureVertex(position: .init(from: p2.position), texcoord: .init(from: p2.texPos)),
                FreeDrawTextureVertex(position: .init(from: p3.position), texcoord: .init(from: p3.texPos))
        )
    }
}

extension SIMD2<Float> {
    init(from vector: vec2) {
        self.init(vector.x, vector.y)
    }
}
