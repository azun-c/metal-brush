//
//  ViewController.swift
//  metal-brush
//
//  Created by azun on 21/02/2024.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var freeDrawView: FreeDrawView = {
        let freeDrawView = FreeDrawView(frame: .zero)
        freeDrawView.translatesAutoresizingMaskIntoConstraints = false
        
        let state = DrawingCurveState(for: freeDrawView)
        freeDrawView.viewState = state
        state.onBeginState()
        return freeDrawView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
}

private extension ViewController {
    func setupUI() {
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        view.addSubview(freeDrawView)
        NSLayoutConstraint.activate([
            freeDrawView.topAnchor.constraint(equalTo: view.topAnchor),
            freeDrawView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            freeDrawView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            freeDrawView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
