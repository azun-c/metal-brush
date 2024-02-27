//
//  ViewStateProtocol.swift
//  metal-brush
//
//  Created by azun on 26/02/2024.
//

import Foundation
import UIKit

protocol ViewStateProtocol {
    var view: FreeDrawProtocol? { get set }
    
    func onRender()
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
}
