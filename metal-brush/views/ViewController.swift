//
//  ViewController.swift
//  metal-brush
//
//  Created by azun on 21/02/2024.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var lastScale: CGFloat = 1.0
    private var lastPoint = CGPointZero
    
    private lazy var backdropView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        return view
    }()
    
    private var freeDrawView: FreeDrawView = {
        let freeDrawView = FreeDrawView(frame: .zero)
        freeDrawView.translatesAutoresizingMaskIntoConstraints = false
        
        let state = DrawingCurveState(for: freeDrawView)
        freeDrawView.viewState = state
        return freeDrawView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupEffects()
    }
}

private extension ViewController {
    func setupUI() {
        view.addSubview(backdropView)
        backdropView.addSubview(freeDrawView)
        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            backdropView.widthAnchor.constraint(equalTo: backdropView.heightAnchor, multiplier: 1.7),
            
            freeDrawView.topAnchor.constraint(equalTo: backdropView.topAnchor),
            freeDrawView.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
            freeDrawView.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor),
            freeDrawView.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor)
        ])
    }
    
    func setupEffects() {
//        setupBackgroundEffect()
        setupZoomInEffect()
    }
    
    func setupBackgroundEffect() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let seconds = Calendar.current.component(.second, from: Date())
            self.backdropView.backgroundColor = seconds % 10 >= 4 ? UIColor.white : .cyan
        })
        timer.fire()
    }
    
    func setupZoomInEffect() {
        let gesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchAction(sender:)))
        view.addGestureRecognizer(gesture)
    }
    
    @objc
    func pinchAction(sender: UIPinchGestureRecognizer) {
        if sender.numberOfTouches < 2 {
            return
        }
        if sender.state == .began {
            lastScale = 1.0
            lastPoint = sender.location(in: view)
        }
        
        // Scale
        let scale = 1.0 - (lastScale - sender.scale)
        view.layer.setAffineTransform(CGAffineTransformScale(view.layer.affineTransform(), scale, scale))
        lastScale = sender.scale
        
        // Translate
        let point = sender.location(in: view)
        view.layer.setAffineTransform(CGAffineTransformTranslate(view.layer.affineTransform(),
                                                                 point.x - lastPoint.x,
                                                                 point.y - lastPoint.y))
        lastPoint = sender.location(in: view)
    }
}
