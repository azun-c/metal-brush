//
//  DrawingCurveState.swift
//  metal-brush
//
//  Created by azun on 26/02/2024.
//

import Foundation
import UIKit

class DrawingCurveState {
    private weak var drawnView: FreeDrawProtocol?
    
    init(for view: FreeDrawProtocol) {
        drawnView = view
    }
}

//MARK: - ViewStateProtocol
extension DrawingCurveState: ViewStateProtocol {
    var view: FreeDrawProtocol? {
        get {
            drawnView
        }
        set {
            drawnView = newValue
        }
    }
    
    func onBeginState() {
        
    }
    
    func onRender() {
        
    }
    
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
}
