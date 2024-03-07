//
//  Scalar+Extensions.swift
//  metal-brush
//
//  Created by azun on 27/02/2024.
//

import Foundation

extension UInt32 {
    var asInt: Int {
        Int(self)
    }
}

extension Int {
    var asFloat: Float {
        Float(self)
    }
}

extension CGFloat {
    var asFloat: Float {
        Float(self)
    }
    
    var asInt: Int {
        Int(self)
    }
}
