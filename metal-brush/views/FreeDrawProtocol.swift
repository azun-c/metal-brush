//
//  FreeDrawProtocol.swift
//  metal-brush
//
//  Created by azun on 26/02/2024.
//

import Foundation
import UIKit

protocol FreeDrawProtocol: UIView {
    var curveWidth: Float { get set }
    var viewState: ViewStateProtocol? { get set }
    var triangles: Triangles { get set }
}
