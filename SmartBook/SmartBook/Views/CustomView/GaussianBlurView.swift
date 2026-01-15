//
//  BlurView.swift
//
//  Created by Andrew on 2024/9/14.
//
import SwiftUI
import UIKit

struct GaussianBlurView: UIViewRepresentable {

    var style: UIBlurEffect.Style? = nil
    var backgroundColor: UIColor = .clear
    var alpha: CGFloat = 1.0


    func makeUIView(context: UIViewRepresentableContext<GaussianBlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.clipsToBounds = true

        let blurEffect = UIBlurEffect(style: style ?? .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = alpha
        blurView.clipsToBounds = true

        view.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        return view
    }

    func updateUIView(
        _ uiView: UIView,
        context: UIViewRepresentableContext<GaussianBlurView>
    ) {

    }

}
