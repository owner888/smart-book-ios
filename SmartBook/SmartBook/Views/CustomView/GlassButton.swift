//
//  GlassButton.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/14.
//

import SwiftUI

extension Button {
    @ViewBuilder
    func glassEffect(size: CGSize = CGSize(width: 40, height: 40)) -> some View {
        if #available(iOS 26, *) {
            self.frame(width: size.width, height: size.height).buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.buttonStyle(.glassIcon)
        }
    }
}
