import SwiftUI
import UIKit

/// Applies the chosen appearance to the window rather than to the root view.
///
/// `preferredColorScheme` puts its override on the root view controller's view.
/// Sheets and covers are presented *on the window*, outside that subtree, so
/// they never picked the override up: choosing Dark inside the Settings sheet
/// left the sheet — and the system UI it presents — on the old scheme until the
/// sheet went away and the root view showed through again.
///
/// Overriding the window instead covers every view controller it hosts,
/// presented or not, so the change lands everywhere at once.
extension View {
    func windowAppearance(_ appearance: AppAppearance) -> some View {
        // Zero-sized so it stays out of layout entirely; it exists only to
        // reach the window it gets added to.
        background(
            WindowStyleApplier(style: appearance.userInterfaceStyle)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

extension AppAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct WindowStyleApplier: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> WindowStyleView {
        let view = WindowStyleView()
        view.isUserInteractionEnabled = false
        view.style = style
        return view
    }

    func updateUIView(_ uiView: WindowStyleView, context: Context) {
        uiView.style = style
    }
}

/// Carries the style down to whichever window it lands in.
///
/// The window is still nil while the view is being made, which is why the
/// stored style is re-applied on `didMoveToWindow` — that pass is what covers
/// launching straight into a saved Light or Dark preference.
private final class WindowStyleView: UIView {
    var style: UIUserInterfaceStyle = .unspecified {
        didSet { applyStyle() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyStyle()
    }

    private func applyStyle() {
        guard let window, window.overrideUserInterfaceStyle != style else {
            return
        }
        window.overrideUserInterfaceStyle = style
    }
}
