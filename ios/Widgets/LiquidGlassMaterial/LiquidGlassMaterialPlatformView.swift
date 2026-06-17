import Flutter
import UIKit

private final class LiquidGlassMaterialRootView: UIView {
    private let effectView: UIVisualEffectView
    private var glassConfig = IosGlassConfig.parse(from: nil)
    private var lastEffectKey: IosGlassEffectKey?
    private lazy var pressFeedback: IosGlassPressFeedbackController = {
        IosGlassPressFeedbackController(
            scaleView: self,
            glowHost: self,
            config: .disabled
        )
    }()

    override init(frame: CGRect) {
        effectView = UIVisualEffectView(
            effect: UIBlurEffect(style: .systemThinMaterial)
        )
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerCurve = .continuous
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.backgroundColor = .clear
        effectView.clipsToBounds = true
        effectView.layer.cornerCurve = .continuous
        effectView.isUserInteractionEnabled = false
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        IosGlassUnionRegistry.shared.unregister(view: self)
    }

    func configure(config: IosGlassConfig) {
        glassConfig = config
        IosGlassSurface.apply(
            root: self,
            effectView: effectView,
            config: config,
            pressFeedback: pressFeedback,
            lastEffectKey: &lastEffectKey
        )
    }

    func setPressed(_ pressed: Bool, at point: CGPoint?) {
        pressFeedback.setPressed(pressed, at: point)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        IosGlassShapeApplier.apply(
            to: self,
            effectView: effectView,
            config: glassConfig,
            pressFeedback: pressFeedback
        )
        IosGlassUnionRegistry.shared.register(
            view: self,
            effectView: effectView,
            config: glassConfig
        )
    }
}

final class LiquidGlassMaterialPlatformView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let rootView: LiquidGlassMaterialRootView
    private var methodChannel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        rootView = LiquidGlassMaterialRootView(frame: frame)
        super.init()
        IosPlatformViewCompositor.shared.register(
            viewId: viewId,
            view: rootView,
            policy: .none
        )
        applyArgs(args)
        let channel = FlutterMethodChannel(
            name: "liquid_glass_material_\(viewId)",
            binaryMessenger: messenger
        )
        methodChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DISPOSED", message: nil, details: nil))
                return
            }
            switch call.method {
            case "update":
                self.applyArgs(call.arguments)
                result(nil)
            case "touchDown":
                self.handleTouchDown(call.arguments)
                result(nil)
            case "touchUp", "touchCancel":
                self.rootView.setPressed(false, at: nil)
                result(nil)
            default:
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

    private func handleTouchDown(_ args: Any?) {
        guard let dict = args as? [String: Any] else {
            rootView.setPressed(true, at: nil)
            return
        }
        let x = CGFloat(truncating: (dict["x"] as? NSNumber) ?? 0)
        let y = CGFloat(truncating: (dict["y"] as? NSNumber) ?? 0)
        rootView.setPressed(true, at: CGPoint(x: x, y: y))
    }

    private func applyArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }
        rootView.configure(config: IosGlassConfig.parse(from: dict))
    }
}
