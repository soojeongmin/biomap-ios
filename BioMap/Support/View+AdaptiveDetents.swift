import SwiftUI
import UIKit

private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

extension View {
    @ViewBuilder
    func adaptiveDetents() -> some View {
        if isPad {
            if #available(iOS 18.0, *) {
                presentationSizing(.page)
            } else {
                self
            }
        } else {
            presentationDetents([.medium, .large])
        }
    }

    func padContentWidth(_ max: CGFloat = 640) -> some View {
        frame(maxWidth: isPad ? max : .infinity)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func largeSheet() -> some View {
        if isPad {
            if #available(iOS 18.0, *) {
                presentationSizing(.page)
            } else {
                self
            }
        } else {
            presentationDetents([.large])
        }
    }
}
