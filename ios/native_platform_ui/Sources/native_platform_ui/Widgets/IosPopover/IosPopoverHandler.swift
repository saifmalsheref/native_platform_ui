import Flutter
import UIKit

/// Presents `UIMenu` on the registered native [IosButtonPlatformView].
@available(iOS 15.0, *)
final class IosPopoverHandler: NSObject {
    private static var eventChannel: FlutterMethodChannel?

    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "ios_native_popover",
            binaryMessenger: messenger
        )
        eventChannel = FlutterMethodChannel(
            name: "ios_native_popover_events",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "presentMenu":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Expected map",
                        details: nil
                    ))
                    return
                }
                presentMenu(args: args, flutterResult: result)
            case "presentMenuAtAnchor":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Expected map",
                        details: nil
                    ))
                    return
                }
                presentMenuAtAnchor(args: args, flutterResult: result)
            case "dismiss":
                if let args = call.arguments as? [String: Any] {
                    notifyPresentation(
                        transitionId: args["transitionId"] as? String ?? "",
                        presented: false
                    )
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static var anchorPresenters: [ObjectIdentifier: IosAnchorMenuPresenter] = [:]

    private static func presentationHostView() -> UIView? {
        if let window = keyWindow(),
           let flutterController = window.rootViewController as? FlutterViewController {
            return flutterController.view
        }
        return keyWindow()
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private static func topViewController(from view: UIView?) -> UIViewController? {
        if let view {
            var responder: UIResponder? = view
            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }
                responder = current.next
            }
        }
        var controller = keyWindow()?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    private static func parseMenuItems(_ args: [String: Any]) -> [IosPopoverMenuItem] {
        let rawActions = args["actions"] as? [[String: Any]] ?? []
        return rawActions.map { entry in
            IosPopoverMenuItem(
                title: entry["title"] as? String ?? "",
                systemImage: entry["systemImage"] as? String,
                isDestructive: entry["isDestructive"] as? Bool ?? false
            )
        }
    }

    private static func presentMenuAtAnchor(
        args: [String: Any],
        flutterResult: @escaping FlutterResult
    ) {
        dismissStaleAnchors()

        guard let host = presentationHostView() else {
            flutterResult(FlutterError(
                code: "NO_HOST_VIEW",
                message: "Flutter host view unavailable",
                details: nil
            ))
            return
        }

        let items = parseMenuItems(args)
        guard !items.isEmpty else {
            flutterResult(FlutterError(
                code: "NO_ACTIONS",
                message: "At least one action required",
                details: nil
            ))
            return
        }

        let x = CGFloat(truncating: (args["x"] as? NSNumber) ?? 0)
        let y = CGFloat(truncating: (args["y"] as? NSNumber) ?? 0)
        let width = CGFloat(truncating: (args["width"] as? NSNumber) ?? 44)
        let height = CGFloat(truncating: (args["height"] as? NSNumber) ?? 44)

        // Flutter `localToGlobal` uses the same logical coordinate space as the
        // FlutterView — place the anchor directly on top of the Flutter surface.
        let localFrame = CGRect(
            x: x,
            y: y,
            width: max(width, 44),
            height: max(height, 44)
        )

        let anchorView = UIView(frame: localFrame)
        anchorView.backgroundColor = .clear
        anchorView.isUserInteractionEnabled = true
        host.addSubview(anchorView)
        host.bringSubviewToFront(anchorView)

        let layoutRtl = args["layoutRtl"] as? Bool ?? false
        let cancelTitle = args["cancelTitle"] as? String ?? "Cancel"

        let presenter = IosAnchorMenuPresenter(
            items: items,
            anchorView: anchorView,
            presentingViewController: topViewController(from: host),
            layoutRtl: layoutRtl,
            cancelTitle: cancelTitle
        )
        anchorPresenters[ObjectIdentifier(presenter)] = presenter
        presenter.present()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        flutterResult(nil)
    }

    fileprivate static func removeAnchorPresenter(_ presenter: IosAnchorMenuPresenter) {
        anchorPresenters.removeValue(forKey: ObjectIdentifier(presenter))
    }

    private static func dismissStaleAnchors() {
        for presenter in anchorPresenters.values {
            presenter.forceCleanup()
        }
        anchorPresenters.removeAll()
    }

    fileprivate static func notifyAnchorMenuSelected(_ index: Int) {
        DispatchQueue.main.async {
            eventChannel?.invokeMethod("anchorMenuSelected", arguments: index)
        }
    }

    fileprivate static func notifyAnchorMenuDismissed() {
        DispatchQueue.main.async {
            eventChannel?.invokeMethod("anchorMenuDismissed", arguments: nil)
        }
    }

    static func notifyPresentation(transitionId: String, presented: Bool) {
        guard !transitionId.isEmpty else { return }
        eventChannel?.invokeMethod(
            "presentationChanged",
            arguments: [
                "transitionId": transitionId,
                "presented": presented,
            ]
        )
    }

    private static func presentMenu(args: [String: Any], flutterResult: @escaping FlutterResult) {
        guard let viewId = args["nativeButtonViewId"] as? Int64,
              let buttonView = IosNativeButtonRegistry.shared.view(for: viewId) else {
            flutterResult(FlutterError(
                code: "NO_BUTTON",
                message: "nativeButtonViewId required",
                details: nil
            ))
            return
        }

        let items = parseMenuItems(args)
        guard !items.isEmpty else {
            flutterResult(FlutterError(
                code: "NO_ACTIONS",
                message: "At least one action required",
                details: nil
            ))
            return
        }

        let transitionId = args["transitionId"] as? String ?? ""
        let cornerRadius = CGFloat(
            truncating: (args["sourceCornerRadius"] as? NSNumber) ?? 12
        )

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        buttonView.presentPopoverMenu(
            items: items,
            transitionId: transitionId,
            cornerRadius: cornerRadius,
            flutterResult: flutterResult
        )
    }
}

struct IosPopoverMenuItem {
    let title: String
    let systemImage: String?
    let isDestructive: Bool
}

@available(iOS 15.0, *)
private final class IosAnchorMenuPresenter: NSObject {
    let items: [IosPopoverMenuItem]
    weak var anchorView: UIView?
    private weak var presentingViewController: UIViewController?
    private let layoutRtl: Bool
    private let cancelTitle: String
    private var completed = false

    init(
        items: [IosPopoverMenuItem],
        anchorView: UIView,
        presentingViewController: UIViewController?,
        layoutRtl: Bool,
        cancelTitle: String
    ) {
        self.items = items
        self.anchorView = anchorView
        self.presentingViewController = presentingViewController
        self.layoutRtl = layoutRtl
        self.cancelTitle = cancelTitle
        super.init()
    }

    func present() {
        guard anchorView != nil else { return }

        if #available(iOS 17.4, *) {
            presentPrimaryActionMenu()
        } else {
            presentActionSheetFallback()
        }
    }

    @available(iOS 17.4, *)
    private func presentPrimaryActionMenu() {
        guard let anchorView else { return }

        let button = UIButton(type: .system)
        button.frame = anchorView.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.backgroundColor = .clear
        button.semanticContentAttribute = layoutRtl
            ? .forceRightToLeft
            : .forceLeftToRight
        button.menu = buildMenu()
        button.showsMenuAsPrimaryAction = true
        anchorView.addSubview(button)

        anchorView.layoutIfNeeded()
        // Defer until the Flutter tap that triggered this menu has ended.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self, weak button] in
            guard let self, let button, !self.completed else { return }
            button.performPrimaryAction()
        }
    }

    func forceCleanup() {
        guard !completed else { return }
        completed = true
        anchorView?.removeFromSuperview()
    }

    private func presentActionSheetFallback() {
        guard
            let anchorView,
            let presenter = presentingViewController
        else {
            finishDismissed()
            return
        }

        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        applyLayoutDirection(to: sheet, rtl: layoutRtl)
        for (index, item) in items.enumerated() {
            sheet.addAction(
                UIAlertAction(
                    title: item.title,
                    style: item.isDestructive ? .destructive : .default
                ) { [weak self] _ in
                    self?.finish(selectedIndex: index)
                }
            )
        }
        sheet.addAction(
            UIAlertAction(title: cancelTitle, style: .cancel) { [weak self] _ in
                self?.finishDismissed()
            }
        )

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = anchorView
            popover.sourceRect = anchorView.bounds
            popover.permittedArrowDirections = [.up, .down]
        }

        presenter.present(sheet, animated: true) { [weak self] in
            if sheet.view.window == nil {
                self?.finishDismissed()
            }
        }
    }

    @available(iOS 17.4, *)
    private func buildMenu() -> UIMenu {
        let actions: [UIAction] = items.enumerated().map { index, item in
            let image = item.systemImage.flatMap { UIImage(systemName: $0) }
            return UIAction(
                title: item.title,
                image: image,
                attributes: item.isDestructive ? .destructive : []
            ) { [weak self] _ in
                self?.finish(selectedIndex: index)
            }
        }
        return UIMenu(title: "", options: .displayInline, children: actions)
    }

    private func finish(selectedIndex: Int) {
        guard !completed else { return }
        completed = true
        anchorView?.removeFromSuperview()
        IosPopoverHandler.removeAnchorPresenter(self)
        IosPopoverHandler.notifyAnchorMenuSelected(selectedIndex)
    }

    private func finishDismissed() {
        guard !completed else { return }
        completed = true
        anchorView?.removeFromSuperview()
        IosPopoverHandler.removeAnchorPresenter(self)
        IosPopoverHandler.notifyAnchorMenuDismissed()
    }

    private func applyLayoutDirection(to sheet: UIAlertController, rtl: Bool) {
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        sheet.view.semanticContentAttribute = attr
    }
}

/// Preview chip that morphs into the menu (Safari ellipsis chip).
final class IosMenuSourcePreviewController: UIViewController {
    init(size: CGSize, cornerRadius: CGFloat) {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = size
        let preview = UIView(frame: CGRect(origin: .zero, size: size))
        preview.backgroundColor = .secondarySystemGroupedBackground
        preview.layer.cornerRadius = cornerRadius
        preview.layer.cornerCurve = .continuous
        preview.clipsToBounds = true
        view = preview
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
