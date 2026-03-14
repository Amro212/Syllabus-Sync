import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var primaryColor: Color? = nil
    /// Overrides the stroke width in Lottie units (canvas is 430×430).
    /// At a 16pt frame, set ~45 to get ≈1.7pt visible strokes.
    var strokeWidth: CGFloat? = nil
    var playTrigger: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false

        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.isUserInteractionEnabled = false
        animationView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        applyOverrides(to: animationView)
        animationView.currentProgress = 1
        context.coordinator.animationView = animationView
        context.coordinator.lastTrigger = playTrigger

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }
        applyOverrides(to: animationView)

        if playTrigger != context.coordinator.lastTrigger {
            context.coordinator.lastTrigger = playTrigger
            animationView.currentProgress = 0
            animationView.play()
        }
    }

    private func applyOverrides(to view: LottieAnimationView) {
        if let primary = primaryColor {
            let provider = ColorValueProvider(primary.lottieColorValue)
            // "**.Color" matches any Color property at any depth regardless of layer naming,
            // which is required because these animations name their stroke layers ".primary"/".secondary"
            // (with a leading dot) — making name-based keypaths unable to match them.
            view.setValueProvider(provider, keypath: AnimationKeypath(keypath: "**.Color"))
        }
        if let width = strokeWidth {
            let provider = FloatValueProvider(width)
            view.setValueProvider(provider, keypath: AnimationKeypath(keypath: "**.Stroke Width"))
        }
    }

    class Coordinator {
        var animationView: LottieAnimationView?
        var lastTrigger: Bool = false
    }
}

private extension Color {
    var lottieColorValue: LottieColor {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return LottieColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }
}
