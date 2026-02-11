//
//  UIBlurView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/10.
//

import UIKit

class UIBlurView: UIView {

    var style: UIBlurEffect.Style? = nil
    var background: UIColor = .clear
    var opacity: CGFloat = 1.0
    
    var clearGlassEffect = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    func setUp() {
        self.backgroundColor = .clear
        let backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(backgroundView)
        var kBlurView: UIView?
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(
                style: clearGlassEffect ? .clear : .regular
            )
            glassEffect.tintColor = backgroundColor
            glassEffect.isInteractive = true
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.frame = self.bounds

            if !clearGlassEffect {
                if let style = style {
                    effectView.overrideUserInterfaceStyle =
                        style == .dark ? .dark : .light
                }
            }

            effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.addSubview(effectView)
            kBlurView = effectView
        } else {
            backgroundView.backgroundColor = backgroundColor
            let blurEffect = UIBlurEffect(style: style ?? .dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.alpha = alpha
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
            vibrancyView.frame = blurView.bounds
            vibrancyView.autoresizingMask = [
                .flexibleWidth, .flexibleHeight,
            ]
            blurView.contentView.addSubview(vibrancyView)
            self.addSubview(blurView)
            kBlurView = blurView
        }
        NSLayoutConstraint.activate([
            kBlurView!.heightAnchor.constraint(equalTo: self.heightAnchor),
            kBlurView!.widthAnchor.constraint(equalTo: self.widthAnchor),
            backgroundView.heightAnchor.constraint(
                equalTo: self.heightAnchor
            ),
            backgroundView.widthAnchor.constraint(
                equalTo: self.widthAnchor
            ),
        ])
    }


}
