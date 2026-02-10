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
    @Environment(\.colorScheme) private var colorScheme


    func makeUIView(context: UIViewRepresentableContext<GaussianBlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = backgroundColor
        view.clipsToBounds = true

        let blurEffect = UIBlurEffect(style: style ?? (colorScheme == .dark ?  .dark : .light))
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
        // 当style为nil时，根据colorScheme变化更新blur effect
        if style == nil {
            if let blurView = uiView.subviews.first as? UIVisualEffectView {
                let newStyle = colorScheme == .dark ? UIBlurEffect.Style.dark : .light
                let newBlurEffect = UIBlurEffect(style: newStyle)
                blurView.effect = newBlurEffect
            }
        }

        // 更新其他属性
        uiView.backgroundColor = backgroundColor
        if let blurView = uiView.subviews.first as? UIVisualEffectView {
            blurView.alpha = alpha
        }
    }

}
