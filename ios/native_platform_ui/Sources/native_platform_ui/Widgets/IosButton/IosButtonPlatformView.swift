import Flutter
import UIKit

@available(iOS 15.0, *)
final class IosButtonGlassRootView: UIView {
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

    /// Host for buttons / stacks — must live inside the glass `contentView`.
    var contentHost: UIView { effectView.contentView }

    override init(frame: CGRect) {
        effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.isUserInteractionEnabled = true
        effectView.clipsToBounds = true
        effectView.layer.cornerCurve = .continuous
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

    var pressFeedbackController: IosGlassPressFeedbackController { pressFeedback }

    func applyGlass(config: IosGlassConfig) {
        glassConfig = config
        isUserInteractionEnabled = true
        effectView.isUserInteractionEnabled = true
        IosGlassSurface.apply(
            root: self,
            effectView: effectView,
            config: config,
            pressFeedback: pressFeedback,
            lastEffectKey: &lastEffectKey,
            contentHost: contentHost
        )
    }

    func setPressed(_ pressed: Bool, at point: CGPoint? = nil) {
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
        let radius = IosGlassShapeApplier.resolvedCornerRadius(
            config: glassConfig,
            in: bounds
        )
        contentHost.layer.cornerRadius = radius
        contentHost.clipsToBounds = true
        IosGlassUnionRegistry.shared.register(
            view: self,
            effectView: effectView,
            config: glassConfig
        )
    }
}

@available(iOS 15.0, *)
final class IosButtonPlatformView: NSObject, FlutterPlatformView, UIContextMenuInteractionDelegate {
    private let viewId: Int64
    private let rootView: IosButtonGlassRootView
    private let button: UIButton
    private var methodChannel: FlutterMethodChannel?
    private var menuInteraction: UIContextMenuInteraction?
    private var hasLongPressHandler = false
    private var popoverMode = false
    private var popoverMenuItems: [IosPopoverMenuItem] = []
    private var popoverTransitionId = ""
    private var menuIsVisible = false
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
        button = UIButton(type: .custom)
        super.init()

        button.translatesAutoresizingMaskIntoConstraints = false
        rootView.contentHost.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: rootView.contentHost.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: rootView.contentHost.trailingAnchor),
            button.topAnchor.constraint(equalTo: rootView.contentHost.topAnchor),
            button.bottomAnchor.constraint(equalTo: rootView.contentHost.bottomAnchor),
        ])

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(onLongPress(_:))
        )
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = false
        button.addGestureRecognizer(longPress)

        let interaction = UIContextMenuInteraction(delegate: self)
        button.addInteraction(interaction)
        menuInteraction = interaction

        IosNativeButtonRegistry.shared.register(viewId: viewId, view: self)
        IosPlatformViewCompositor.shared.register(viewId: viewId, view: rootView)

        applyArgs(args)
        IosGlassPressHandler.wire(
            on: button,
            feedback: rootView.pressFeedbackController,
            glowHost: rootView
        )

        let channel = FlutterMethodChannel(
            name: "ios_native_button_\(viewId)",
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
        IosNativeButtonRegistry.shared.unregister(viewId: viewId)
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
    }

    func view() -> UIView {
        rootView
    }

    @objc private func onTap() {
        guard button.isEnabled else { return }
        if popoverMode {
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        methodChannel?.invokeMethod("pressed", arguments: nil)
    }

    @objc private func onLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard button.isEnabled, hasLongPressHandler else { return }
        guard recognizer.state == .began else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        methodChannel?.invokeMethod("longPressed", arguments: nil)
    }

    private func applyPopoverMenu() {
        let wasPopoverMode = popoverMode
        popoverMode = !popoverMenuItems.isEmpty

        button.removeTarget(self, action: #selector(onTap), for: .touchUpInside)

        if popoverMode {
            if !menuIsVisible {
                button.menu = buildPopoverUIMenu()
            }
            button.showsMenuAsPrimaryAction = true
            button.changesSelectionAsPrimaryAction = false
            if let interaction = menuInteraction {
                button.removeInteraction(interaction)
                menuInteraction = nil
            }
        } else {
            button.menu = nil
            button.showsMenuAsPrimaryAction = false
            button.addTarget(self, action: #selector(onTap), for: .touchUpInside)
            if menuInteraction == nil {
                let interaction = UIContextMenuInteraction(delegate: self)
                button.addInteraction(interaction)
                menuInteraction = interaction
            }
        }

        if wasPopoverMode != popoverMode, !popoverMode {
            menuIsVisible = false
            rootView.alpha = 1
        }
    }

    private func buildPopoverUIMenu() -> UIMenu {
        let actions: [UIAction] = popoverMenuItems.enumerated().map { index, item in
            let image = item.systemImage.flatMap { UIImage(systemName: $0) }
            return UIAction(
                title: item.title,
                image: image,
                attributes: item.isDestructive ? .destructive : []
            ) { [weak self] _ in
                guard let self else { return }
                self.menuIsVisible = false
                self.rootView.alpha = 1
                self.notifyPopoverPresentation(presented: false)
                self.methodChannel?.invokeMethod("popoverSelected", arguments: index)
            }
        }
        return UIMenu(title: "", options: .displayInline, children: actions)
    }

    private func notifyPopoverPresentation(presented: Bool) {
        guard !popoverTransitionId.isEmpty else { return }
        IosPopoverHandler.notifyPresentation(
            transitionId: popoverTransitionId,
            presented: presented
        )
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        nil
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        menuIsVisible = true
        notifyPopoverPresentation(presented: true)
        animator?.addAnimations { [weak self] in
            self?.rootView.alpha = 0
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        menuIsVisible = false
        animator?.addAnimations { [weak self] in
            self?.rootView.alpha = 1
        }
        animator?.addCompletion { [weak self] in
            self?.notifyPopoverPresentation(presented: false)
        }
    }

    private func applyArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }

        let glassConfig = IosGlassConfig.parse(from: dict)
        interactionConfig = glassConfig.interaction
        let cornerRadius = glassConfig.cornerRadius
        let enabled = dict["enabled"] as? Bool ?? true
        hasLongPressHandler = dict["hasLongPress"] as? Bool ?? false
        popoverTransitionId = dict["popoverTransitionId"] as? String ?? ""

        let previousPopoverItems = popoverMenuItems
        if let rawActions = dict["popoverActions"] as? [[String: Any]] {
            popoverMenuItems = rawActions.map { entry in
                IosPopoverMenuItem(
                    title: entry["title"] as? String ?? "",
                    systemImage: entry["systemImage"] as? String,
                    isDestructive: entry["isDestructive"] as? Bool ?? false
                )
            }
        } else {
            popoverMenuItems = []
        }

        rootView.applyGlass(config: glassConfig)

        button.isEnabled = enabled
        if !menuIsVisible {
            rootView.alpha = enabled ? 1 : 0.45
        }

        var config = IosButtonNativeChrome.borderlessConfiguration(
            cornerRadius: cornerRadius,
            inGlassContainer: true
        )

        if let symbol = dict["sfSymbol"] as? String, !symbol.isEmpty {
            let pointSize = CGFloat(truncating: (dict["iconSize"] as? NSNumber) ?? 22)
            config.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: pointSize,
                    weight: .regular
                )
            )
        } else {
            config.image = nil
        }

        if let title = dict["title"] as? String, !title.isEmpty {
            config.title = title
        } else {
            config.title = nil
        }

        if config.image != nil, config.title != nil {
            config.imagePlacement = .leading
            config.titleAlignment = .leading
            config.imagePadding = 8
        }

        if let iconArgb = dict["iconColor"] as? NSNumber {
            let v = iconArgb.int64Value
            if v >= 0 {
                config.baseForegroundColor = Self.uiColor(fromArgb: v)
            }
        }

        if dict["paddingTop"] != nil
            || dict["paddingLeading"] != nil
            || dict["paddingBottom"] != nil
            || dict["paddingTrailing"] != nil {
            config.contentInsets = NSDirectionalEdgeInsets(
                top: CGFloat(truncating: (dict["paddingTop"] as? NSNumber) ?? 0),
                leading: CGFloat(truncating: (dict["paddingLeading"] as? NSNumber) ?? 0),
                bottom: CGFloat(truncating: (dict["paddingBottom"] as? NSNumber) ?? 0),
                trailing: CGFloat(truncating: (dict["paddingTrailing"] as? NSNumber) ?? 0)
            )
        }

        button.configuration = config

        let nextPopoverMode = !popoverMenuItems.isEmpty
        let popoverItemsChanged = !Self.popoverMenuItemsEqual(
            previousPopoverItems,
            popoverMenuItems
        )
        if nextPopoverMode != popoverMode
            || popoverItemsChanged
            || !menuIsVisible {
            applyPopoverMenu()
        }
    }

    private static func popoverMenuItemsEqual(
        _ lhs: [IosPopoverMenuItem],
        _ rhs: [IosPopoverMenuItem]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (a, b) in zip(lhs, rhs) {
            if a.title != b.title
                || a.systemImage != b.systemImage
                || a.isDestructive != b.isDestructive {
                return false
            }
        }
        return true
    }

    func presentPopoverMenu(
        items: [IosPopoverMenuItem],
        transitionId: String,
        cornerRadius: CGFloat,
        flutterResult: @escaping FlutterResult
    ) {
        popoverTransitionId = transitionId
        popoverMenuItems = items
        applyPopoverMenu()
        flutterResult(nil)
    }

    static func uiColor(fromArgb argb: Int64) -> UIColor {
        IosGlassEffectFactory.uiColor(fromArgb: argb)
    }
}
