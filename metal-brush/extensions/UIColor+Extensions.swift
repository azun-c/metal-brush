//
//  UIColor+Extensions.swift
//  metal-brush
//
//  Created by azun on 29/02/2024.
//

import UIKit

extension UIColor {
    var rgba: (red: Float, green: Float, blue: Float, alpha: Float) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red.asFloat, green.asFloat, blue.asFloat, alpha.asFloat)
    }
    
    var asSIMD4: SIMD4<Float> {
        .init(rgba.red, rgba.green, rgba.blue, rgba.alpha)
    }
}
