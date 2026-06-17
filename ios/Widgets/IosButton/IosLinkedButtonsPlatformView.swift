import Flutter
import UIKit

struct IosLinkedButtonSpec {
    let sfSymbol: String?
    let title: String?
    let enabled: Bool
    let iconColorArgb: Int64?
    let iconSize: CGFloat
}

@available(iOS 15.0, *)
final class IosLinkedButtonsPlatformView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let rootView: IosButtonGlassRootView
    private let stackView: UIStackView
    private var methodChannel: FlutterMethodChannel?
    private var buttonSpecs: [IosLinkedButtonSpec] = []
    private var interactionConfig = IosGlassInteractionConfig(
        nativeInteractive: true,
        pressScale: true,
        pressGlow: true
    )

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        rootView = IosButtonGlassRootView(frame: frame)
        stackView = UIStackView()
        super.init()

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        rootView.contentHost.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: rootView.contentHost.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: rootView.contentHost.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: rootView.contentHost.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: rootView.contentHost.bottomAnchor),
        ])

        IosPlatformViewCompositor.shared.register(viewId: viewId, view: rootView)

        applyArgs(args)

        let channel = FlutterMethodChannel(
            name: "ios_native_linked_buttons_\(viewId)",
            binaryMessenger: messenger
        )
        methodChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DISPOSED", message: nil, details: nil))
                return
            }
            if call.method == "update" {
                self.applyArgs(call.arguments)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    deinit {
        IosPlatformViewCompositor.shared.unregister(viewId: viewId)
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
    }

    func view() -> UIView {
        rootView
    }

    @objc private func linkedTapped(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        methodChannel?.invokeMethod("linkedButtonPressed", arguments: sender.tag)
    }

    private func applyArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }

        let glassConfig = IosGlassConfig.parse(from: dict)
        interactionConfig = glassConfig.interaction
        let defaultIconSize = CGFloat(truncating: (dict["iconSize"] as? NSNumber) ?? 18)

        rootView.applyGlass(config: glassConfig)

        if let spacing = glassConfig.containerSpacing, spacing > 0 {
            stackView.spacing = spacing
        }

        let rawItems = dict["linkedButtons"] as? [[String: Any]] ?? []
        buttonSpecs = rawItems.map { entry in
            IosLinkedButtonSpec(
                sfSymbol: entry["sfSymbol"] as? String,
                title: entry["title"] as? String,
                enabled: entry["enabled"] as? Bool ?? true,
                iconColorArgb: (entry["iconColor"] as? NSNumber)?.int64Value,
                iconSize: CGFloat(
                    truncating: (entry["iconSize"] as? NSNumber)
                        ?? NSNumber(value: Double(defaultIconSize))
                )
            )
        }
        rebuildButtons()
    }

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, spec) in buttonSpecs.enumerated() {
            stackView.addArrangedSubview(makeButton(spec: spec, index: index))
        }
    }

    private func makeButton(spec: IosLinkedButtonSpec, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = index
        button.isEnabled = spec.enabled
        button.alpha = spec.enabled ? 1 : 0.45
        button.addTarget(self, action: #selector(linkedTapped(_:)), for: .touchUpInside)

        if interactionConfig.pressScale || interactionConfig.pressGlow {
            let segmentFeedback = IosGlassPressFeedbackController(
                scaleView: button,
                glowHost: button,
                config: interactionConfig
            )
            IosGlassPressHandler.wire(on: button, feedback: segmentFeedback, glowHost: button)
        }

        var config = IosButtonNativeChrome.borderlessConfiguration(
            cornerRadius: 0,
            inGlassContainer: true
        )

        if let symbol = spec.sfSymbol, !symbol.isEmpty {
            config.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: spec.iconSize,
                    weight: .regular
                )
            )
        }

        if let title = spec.title, !title.isEmpty {
            config.title = title
        }

        if let argb = spec.iconColorArgb, argb >= 0 {
            config.baseForegroundColor = IosGlassEffectFactory.uiColor(fromArgb: argb)
        }

        button.configuration = config
        return button
    }
}
