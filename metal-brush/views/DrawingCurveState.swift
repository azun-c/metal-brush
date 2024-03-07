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
    
    private var currentPolyline = Polyline()
    
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
    
    func onRender() {
        prepareTriangles()
    }
    
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1 else {
            currentPolyline.m_points.clear()
            return
        }
        guard let touch = touches.first, let view else { return }
        let point = touch.location(in: view)
        
        currentPolyline.m_points.clear()
        currentPolyline.addPoint(vec2(point.x.asFloat, point.y.asFloat))
        
        addAnExtraPointBeside(point)
    }
    
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1 else {
            currentPolyline.m_points.clear()
            return
        }
        
        guard let touch = touches.first, let view, let event else { return }
        let point = touch.location(in: view)
        
        currentPolyline.addPoint(vec2(point.x.asFloat, point.y.asFloat))
        
        if (event.allTouches?.count ?? 1) > 1 {
            currentPolyline.m_points.clear()
        }
    }
    
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1 else {
            currentPolyline.m_points.clear()
            return
        }
        
        guard let touch = touches.first, let view else { return }
        let point = touch.location(in: view)
        
        currentPolyline.addPoint(vec2(point.x.asFloat, point.y.asFloat))
        
        addAnExtraPointBeside(point)
        currentPolyline.m_points.clear()
    }
}

//MARK: - Private
private extension DrawingCurveState {
    func addAnExtraPointBeside(_ currentPoint: CGPoint) {
        // workaround: 1 point won't show on screen
        currentPolyline.addPoint(vec2(currentPoint.x.asFloat + 0.1,
                                      currentPoint.y.asFloat + 0.1))
    }
    
    func generateTriangles() -> Triangles {
        var tris = Triangles()
        
        guard let curveWidth = view?.curveWidth else { return tris }
        
        var interpolated:Polyline = Polyline()
        InterpolateAsSNS(currentPolyline, &interpolated)
        PolylineToTriangles(interpolated, curveWidth, &tris)
        return tris
    }
    
    func prepareTriangles() {
        guard currentPolyline.m_points.isEmpty else {
            view?.triangles = generateTriangles()
            return
        }
        
        let shouldReset = view?.triangles.m_triangles.isEmpty == false
        if shouldReset {
            view?.triangles = Triangles()
        }
    }
}
