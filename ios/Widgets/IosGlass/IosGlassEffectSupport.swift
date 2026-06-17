import UIKit

struct IosGlassInteractionConfig: Equatable {
    let nativeInteractive: Bool
    let pressScale: Bool
    let pressGlow: Bool

    var isEnabled: Bool { nativeInteractive || pressScale || pressGlow }

    static let disabled = IosGlassInteractionConfig(
        nativeInteractive: false,
        pressScale: false,
        pressGlow: false
    )

    static func parse(from dict: [String: Any]?) -> IosGlassInteractionConfig {
        guard let dict else { return .disabled }
        let legacy = dict["interactive"] as? Bool
        return IosGlassInteractionConfig(
            nativeInteractive: dict["nativeInteractive"] as? Bool ?? legacy ?? false,
            pressScale: dict["pressScale"] as? Bool ?? legacy ?? false,
            pressGlow: dict["pressGlow"] as? Bool ?? legacy ?? false
        )
    }
}

struct IosGlassEffectKey: Equatable {
    let blurMaterialCodec: Int
    let glassHierarchy: Int
    let prominence: Int

    init(blurMaterialCodec: Int, glassHierarchy: Int, prominence: Int) {
        self.blurMaterialCodec = blurMaterialCodec
        self.glassHierarchy = glassHierarchy
        self.prominence = prominence
    }

    init(config: IosGlassConfig) {
        blurMaterialCodec = config.blurMaterialCodec
        glassHierarchy = config.glassHierarchy
        prominence = config.prominence
    }
}

struct IosGlassConfig: Equatable {
    let cornerRadius: CGFloat
    let shapeKind: Int
    let prominence: Int
    let interaction: IosGlassInteractionConfig
    let tintArgb: Int64?
    let materialBrightness: Int
    let blurMaterialCodec: Int
    let glassHierarchy: Int
    let unionNamespace: String?
    let unionId: String?
    let containerSpacing: CGFloat?

    var isNested: Bool { glassHierarchy == 1 }

    static func parse(from dict: [String: Any]?) -> IosGlassConfig {
        guard let dict else {
            return IosGlassConfig(
                cornerRadius: 16,
                shapeKind: 0,
                prominence: 0,
                interaction: .disabled,
                tintArgb: nil,
                materialBrightness: -1,
                blurMaterialCodec: 5,
                glassHierarchy: 0,
                unionNamespace: nil,
                unionId: nil,
                containerSpacing: nil
            )
        }

        var interaction = IosGlassInteractionConfig.parse(from: dict)
        if dict["nativeInteractive"] == nil && dict["pressScale"] == nil && dict["pressGlow"] == nil {
            let legacy = dict["interactive"] as? Bool ?? false
            interaction = IosGlassInteractionConfig(
                nativeInteractive: legacy,
                pressScale: legacy,
                pressGlow: legacy
            )
        }

        let isCircle = dict["isCircle"] as? Bool ?? false
        let shapeKind: Int = {
            if let v = dict["glassShapeKind"] as? Int { return v }
            if let n = dict["glassShapeKind"] as? NSNumber { return n.intValue }
            return isCircle ? 1 : 0
        }()

        let cornerRadius = CGFloat(
            truncating: (dict["glassCornerRadius"] as? NSNumber)
                ?? (dict["cornerRadius"] as? NSNumber)
                ?? 16
        )

        let prominence: Int = {
            if let v = dict["glassProminence"] as? Int { return v }
            if let n = dict["glassProminence"] as? NSNumber { return n.intValue }
            return 0
        }()

        let tintArgb: Int64? = {
            if let v = dict["tintColor"] as? Int64 { return v }
            if let v = dict["tintColor"] as? Int { return Int64(v) }
            if let n = dict["tintColor"] as? NSNumber { return n.int64Value }
            return nil
        }()

        let materialBrightness: Int = {
            if let v = dict["materialBrightness"] as? Int { return v }
            if let n = dict["materialBrightness"] as? NSNumber { return n.intValue }
            return -1
        }()

        let blurMaterialCodec: Int = {
            if let v = dict["blurMaterial"] as? Int { return v }
            if let n = dict["blurMaterial"] as? NSNumber { return n.intValue }
            return 5
        }()

        let glassHierarchy: Int = {
            if let v = dict["glassHierarchy"] as? Int { return v }
            if let n = dict["glassHierarchy"] as? NSNumber { return n.intValue }
            return 0
        }()

        let containerSpacing: CGFloat? = {
            guard let n = dict["glassContainerSpacing"] as? NSNumber else { return nil }
            return CGFloat(truncating: n)
        }()

        return IosGlassConfig(
            cornerRadius: cornerRadius,
            shapeKind: shapeKind,
            prominence: prominence,
            interaction: interaction,
            tintArgb: tintArgb,
            materialBrightness: materialBrightness,
            blurMaterialCodec: blurMaterialCodec,
            glassHierarchy: glassHierarchy,
            unionNamespace: dict["glassUnionNamespace"] as? String,
            unionId: dict["glassUnionId"] as? String,
            containerSpacing: containerSpacing
        )
    }
}

enum IosGlassShapeApplier {
    static func resolvedCornerRadius(config: IosGlassConfig, in bounds: CGRect) -> CGFloat {
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return config.cornerRadius }

        switch config.shapeKind {
        case 1, 2:
            return side / 2
        case 3:
            return min(config.cornerRadius, side / 2)
        default:
            return min(config.cornerRadius, side / 2)
        }
    }

    static func apply(
        to view: UIView,
        effectView: UIVisualEffectView? = nil,
        config: IosGlassConfig,
        pressFeedback: IosGlassPressFeedbackController? = nil
    ) {
        let radius = resolvedCornerRadius(config: config, in: view.bounds)
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.layer.cornerRadius = radius

        effectView?.layer.cornerCurve = .continuous
        effectView?.clipsToBounds = true
        effectView?.layer.cornerRadius = radius

        if config.shapeKind == 1 {
            view.layer.cornerRadius = radius
            effectView?.layer.cornerRadius = radius
        }

        pressFeedback?.syncCornerRadius(radius)
    }
}

final class IosGlassUnionRegistry {
    static let shared = IosGlassUnionRegistry()

    private struct Entry {
        weak var view: UIView?
        weak var effectView: UIVisualEffectView?
        var config: IosGlassConfig
    }

    private var groups: [String: [Entry]] = [:]
    private let lock = NSLock()

    private func groupKey(namespace: String, unionId: String) -> String {
        "\(namespace)|\(unionId)"
    }

    func register(
        view: UIView,
        effectView: UIVisualEffectView?,
        config: IosGlassConfig
    ) {
        guard let namespace = config.unionNamespace,
              let unionId = config.unionId,
              !namespace.isEmpty,
              !unionId.isEmpty else {
            return
        }

        let key = groupKey(namespace: namespace, unionId: unionId)
        lock.lock()
        defer { lock.unlock() }

        var entries = groups[key] ?? []
        entries.removeAll { $0.view == nil }
        if let index = entries.firstIndex(where: { $0.view === view }) {
            entries[index] = Entry(view: view, effectView: effectView, config: config)
        } else {
            entries.append(Entry(view: view, effectView: effectView, config: config))
        }
        groups[key] = entries
        refreshGroup(key: key)
    }

    func unregister(view: UIView) {
        lock.lock()
        defer { lock.unlock() }

        for (key, entries) in groups {
            let filtered = entries.filter { $0.view !== view && $0.view != nil }
            if filtered.count != entries.count {
                groups[key] = filtered
                refreshGroup(key: key)
            }
        }
    }

    private func refreshGroup(key: String) {
        guard let entries = groups[key]?.filter({ $0.view != nil }), entries.count > 1 else {
            return
        }

        let sorted = entries.sorted {
            let a = $0.view?.convert($0.view?.bounds ?? .zero, to: nil).minX ?? 0
            let b = $1.view?.convert($1.view?.bounds ?? .zero, to: nil).minX ?? 0
            return a < b
        }

        for (index, entry) in sorted.enumerated() {
            guard let view = entry.view else { continue }
            let isFirst = index == 0
            let isLast = index == sorted.count - 1
            let radius = IosGlassShapeApplier.resolvedCornerRadius(
                config: entry.config,
                in: view.bounds
            )

            if entry.config.shapeKind == 2 || sorted.count > 1 {
                if isFirst && isLast {
                    view.layer.maskedCorners = [
                        .layerMinXMinYCorner,
                        .layerMaxXMinYCorner,
                        .layerMinXMaxYCorner,
                        .layerMaxXMaxYCorner,
                    ]
                } else if isFirst {
                    view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
                } else if isLast {
                    view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                } else {
                    view.layer.maskedCorners = []
                }
                view.layer.cornerRadius = radius
                entry.effectView?.layer.cornerRadius = radius
            }
        }
    }
}

enum IosGlassEffectFactory {
    static let blurCodecLiquidGlass = 5

    static func makeEffect(
        blurMaterialCodec: Int,
        nested: Bool = false,
        prominence: Int = 0,
        interactive: Bool,
        tint: UIColor?
    ) -> UIVisualEffect {
        if nested {
            return blurEffectNestedGrouped(forMaterialCodec: blurMaterialCodec)
        }
        if blurMaterialCodec == blurCodecLiquidGlass {
            if let glass = makeUIGlassEffect(
                prominence: prominence,
                interactive: interactive,
                tint: tint
            ) {
                return glass
            }
            return UIBlurEffect(style: .systemThinMaterial)
        }
        return blurEffect(forMaterialCodec: blurMaterialCodec)
    }

    static func makeUIGlassEffect(
        prominence: Int = 0,
        interactive: Bool,
        tint: UIColor?
    ) -> UIVisualEffect? {
        guard #available(iOS 26.0, *), NSClassFromString("UIGlassEffect") != nil,
              let cls = NSClassFromString("UIGlassEffect") as? NSObject.Type else {
            return nil
        }
        let obj = cls.init()
        guard let effect = obj as? UIVisualEffect else { return nil }
        let nsObj = obj as NSObject

        if nsObj.responds(to: NSSelectorFromString("setStyle:")) {
            nsObj.setValue(prominence, forKey: "style")
        } else if nsObj.responds(to: NSSelectorFromString("setProminence:")) {
            nsObj.setValue(prominence, forKey: "prominence")
        }

        if nsObj.responds(to: NSSelectorFromString("setInteractive:")) {
            nsObj.setValue(interactive, forKey: "interactive")
        }
        if let tint, nsObj.responds(to: NSSelectorFromString("setTintColor:")) {
            nsObj.setValue(tint, forKey: "tintColor")
        }
        return effect
    }

    static func blurEffectNestedGrouped(forMaterialCodec _: Int) -> UIBlurEffect {
        UIBlurEffect(style: .systemUltraThinMaterial)
    }

    static func blurEffect(forMaterialCodec codec: Int) -> UIBlurEffect {
        let style: UIBlurEffect.Style
        switch codec {
        case 0: style = .systemUltraThinMaterial
        case 1: style = .systemThinMaterial
        case 2: style = .systemMaterial
        case 3: style = .systemThickMaterial
        case 4: style = .systemChromeMaterial
        default: style = .systemThinMaterial
        }
        return UIBlurEffect(style: style)
    }

    static func uiColor(fromArgb argb: Int64) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xff) / 255.0
        let r = CGFloat((argb >> 16) & 0xff) / 255.0
        let g = CGFloat((argb >> 8) & 0xff) / 255.0
        let b = CGFloat(argb & 0xff) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    static func applyMaterialBrightness(_ codec: Int, to views: UIView...) {
        let style: UIUserInterfaceStyle
        switch codec {
        case 0: style = .light
        case 1: style = .dark
        default: style = .unspecified
        }
        for view in views {
            view.overrideUserInterfaceStyle = style
        }
    }

    static func tint(from config: IosGlassConfig) -> UIColor? {
        guard let argb = config.tintArgb else { return nil }
        return uiColor(fromArgb: argb)
    }
}

final class IosGlassGlowOverlay: UIView {
    private let spotlight = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        clipsToBounds = true
        layer.cornerCurve = .continuous

        spotlight.isUserInteractionEnabled = false
        spotlight.backgroundColor = UIColor.white.withAlphaComponent(0.34)
        spotlight.layer.shadowColor = UIColor.white.cgColor
        spotlight.layer.shadowOpacity = 0.55
        spotlight.layer.shadowRadius = 18
        spotlight.layer.shadowOffset = .zero
        addSubview(spotlight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func syncCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }

    func updateSpotlight(center: CGPoint, in bounds: CGRect) {
        let diameter = max(bounds.width, bounds.height) * 0.72
        spotlight.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        spotlight.center = center
        spotlight.layer.cornerRadius = diameter / 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if spotlight.center == .zero {
            updateSpotlight(center: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds)
        }
    }
}

final class IosGlassPressFeedbackController {
    private weak var scaleView: UIView?
    private let glowOverlay: IosGlassGlowOverlay?
    private var config: IosGlassInteractionConfig

    init(scaleView: UIView, glowHost: UIView?, config: IosGlassInteractionConfig) {
        self.scaleView = scaleView
        self.config = config
        if config.pressGlow, let glowHost {
            let overlay = IosGlassGlowOverlay(frame: glowHost.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.translatesAutoresizingMaskIntoConstraints = false
            glowHost.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: glowHost.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: glowHost.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: glowHost.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: glowHost.bottomAnchor),
            ])
            glowOverlay = overlay
        } else {
            glowOverlay = nil
        }
    }

    func updateConfig(_ config: IosGlassInteractionConfig) {
        self.config = config
    }

    func syncCornerRadius(_ radius: CGFloat) {
        glowOverlay?.syncCornerRadius(radius)
    }

    func setPressed(_ pressed: Bool, at point: CGPoint? = nil) {
        guard config.isEnabled else { return }

        if config.pressScale, let scaleView {
            UIView.animate(
                withDuration: 0.42,
                delay: 0,
                usingSpringWithDamping: 0.68,
                initialSpringVelocity: 0.55,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                scaleView.transform = pressed
                    ? CGAffineTransform(scaleX: 1.06, y: 1.06)
                    : .identity
            }
        }

        guard config.pressGlow, let glowOverlay else { return }
        if let point {
            glowOverlay.updateSpotlight(center: point, in: glowOverlay.bounds)
        } else if glowOverlay.bounds.width > 0 {
            glowOverlay.updateSpotlight(
                center: CGPoint(x: glowOverlay.bounds.midX, y: glowOverlay.bounds.midY),
                in: glowOverlay.bounds
            )
        }
        UIView.animate(
            withDuration: pressed ? 0.16 : 0.28,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            glowOverlay.alpha = pressed ? 1 : 0
        }
    }
}

private enum IosGlassPressHandlerKey {
    static var handler = "iosGlassPressHandler"
}

final class IosGlassPressHandler: NSObject {
    private let feedback: IosGlassPressFeedbackController
    private weak var glowHost: UIView?

    init(feedback: IosGlassPressFeedbackController, glowHost: UIView?) {
        self.feedback = feedback
        self.glowHost = glowHost
        super.init()
    }

    static func wire(on control: UIControl, feedback: IosGlassPressFeedbackController, glowHost: UIView?) {
        let handler = IosGlassPressHandler(feedback: feedback, glowHost: glowHost)
        objc_setAssociatedObject(
            control,
            &IosGlassPressHandlerKey.handler,
            handler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        control.addTarget(handler, action: #selector(touchDown(_:)), for: .touchDown)
        control.addTarget(handler, action: #selector(touchDragInside(_:)), for: .touchDragInside)
        control.addTarget(handler, action: #selector(touchDragOutside(_:)), for: .touchDragOutside)
        control.addTarget(
            handler,
            action: #selector(touchUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
    }

    @objc private func touchDown(_ sender: UIControl) {
        feedback.setPressed(true, at: touchPoint(in: sender))
    }

    @objc private func touchDragInside(_ sender: UIControl) {
        feedback.setPressed(true, at: touchPoint(in: sender))
    }

    @objc private func touchDragOutside(_ sender: UIControl) {
        feedback.setPressed(false)
    }

    @objc private func touchUp(_ sender: UIControl) {
        feedback.setPressed(false)
    }

    private func touchPoint(in control: UIControl) -> CGPoint? {
        guard let glowHost else { return nil }
        let center = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
        return glowHost.convert(center, from: control)
    }
}

/// Shared glass application for platform views.
enum IosGlassSurface {
    static func apply(
        root: UIView,
        effectView: UIVisualEffectView,
        config: IosGlassConfig,
        pressFeedback: IosGlassPressFeedbackController,
        lastEffectKey: inout IosGlassEffectKey?,
        contentHost: UIView? = nil
    ) {
        let tint = IosGlassEffectFactory.tint(from: config)
        IosGlassEffectFactory.applyMaterialBrightness(config.materialBrightness, to: root, effectView)

        let effectKey = IosGlassEffectKey(config: config)
        let needsRebuild = lastEffectKey != effectKey
        if needsRebuild {
            lastEffectKey = effectKey
            effectView.effect = IosGlassEffectFactory.makeEffect(
                blurMaterialCodec: config.blurMaterialCodec,
                nested: config.isNested,
                prominence: config.prominence,
                interactive: config.isNested ? false : config.interaction.nativeInteractive,
                tint: tint
            )
        } else if !config.isNested, config.interaction.nativeInteractive {
            effectView.effect = IosGlassEffectFactory.makeEffect(
                blurMaterialCodec: config.blurMaterialCodec,
                nested: false,
                prominence: config.prominence,
                interactive: true,
                tint: tint
            )
        }

        pressFeedback.updateConfig(config.interaction)
        effectView.isUserInteractionEnabled = config.interaction.nativeInteractive

        IosGlassShapeApplier.apply(
            to: root,
            effectView: effectView,
            config: config,
            pressFeedback: pressFeedback
        )
        if let contentHost {
            let radius = IosGlassShapeApplier.resolvedCornerRadius(config: config, in: root.bounds)
            contentHost.layer.cornerRadius = radius
            contentHost.clipsToBounds = true
        }

        IosGlassUnionRegistry.shared.register(
            view: root,
            effectView: effectView,
            config: config
        )
    }
}
