import Flutter
import UIKit

/// Presents native `UIAlertController` (Liquid Glass on iOS 26+ when available).
enum IosAlertHandler {
    static func present(args: [String: Any], flutterResult: @escaping FlutterResult) {
        guard let title = args["title"] as? String else {
            flutterResult(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "title is required",
                details: nil
            ))
            return
        }

        let message = args["message"] as? String
        let titleColor = color(from: args["titleColor"])
        let messageColor = color(from: args["messageColor"])

        guard let primaryDict = args["primaryButton"] as? [String: Any],
              let primaryText = primaryDict["text"] as? String else {
            flutterResult(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "primaryButton.text is required",
                details: nil
            ))
            return
        }

        let cancelDict = args["cancelButton"] as? [String: Any]
        let layoutRtl = args["layoutRtl"] as? Bool ?? false
        let barrierDismissible = args["barrierDismissible"] as? Bool ?? false
        let materialBrightness = args["materialBrightness"] as? Int

        DispatchQueue.main.async {
            guard let presenter = topViewController() else {
                flutterResult(FlutterError(
                    code: "NO_PRESENTER",
                    message: "No view controller available to present the alert",
                    details: nil
                ))
                return
            }

            if presenter.presentedViewController is UIAlertController {
                flutterResult(FlutterError(
                    code: "ALREADY_PRESENTING",
                    message: "An alert is already being presented",
                    details: nil
                ))
                return
            }

            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            applyUserInterfaceStyle(to: alert, materialBrightness: materialBrightness)
            applyLayoutDirection(to: alert, rtl: layoutRtl)

            applyAttributedText(
                to: alert,
                key: "attributedTitle",
                text: title,
                color: titleColor,
                rtl: layoutRtl
            )
            if let message {
                applyAttributedText(
                    to: alert,
                    key: "attributedMessage",
                    text: message,
                    color: messageColor,
                    rtl: layoutRtl
                )
            }

            var didComplete = false
            let complete: (String) -> Void = { value in
                guard !didComplete else { return }
                didComplete = true
                flutterResult(value)
            }

            var primaryAction: UIAlertAction?

            if let cancelDict, let cancelText = cancelDict["text"] as? String {
                let cancelAction = makeAction(
                    title: cancelText,
                    dict: cancelDict,
                    fallbackStyle: .cancel
                ) {
                    complete("cancel")
                }
                alert.addAction(cancelAction)
            }

            primaryAction = makeAction(
                title: primaryText,
                dict: primaryDict,
                fallbackStyle: .default
            ) {
                complete("primary")
            }
            alert.addAction(primaryAction!)

            if primaryDict["isPreferred"] as? Bool == true {
                alert.preferredAction = primaryAction
            }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            presenter.present(alert, animated: true) {
                if barrierDismissible {
                    IosAlertBarrierDismissHandler.attach(to: alert) {
                        alert.dismiss(animated: true) {
                            complete("dismiss")
                        }
                    }
                }
            }
        }
    }

    private static func applyUserInterfaceStyle(
        to alert: UIAlertController,
        materialBrightness: Int?
    ) {
        guard let materialBrightness else { return }
        let style: UIUserInterfaceStyle
        switch materialBrightness {
        case 0: style = .light
        case 1: style = .dark
        default: return
        }
        alert.overrideUserInterfaceStyle = style
        alert.view.overrideUserInterfaceStyle = style
    }

    private static func makeAction(
        title: String,
        dict: [String: Any],
        fallbackStyle: UIAlertAction.Style,
        handler: @escaping () -> Void
    ) -> UIAlertAction {
        let style = alertStyle(from: dict["style"] as? Int, fallback: fallbackStyle)
        let enabled = dict["enabled"] as? Bool ?? true

        let action = UIAlertAction(title: title, style: style) { _ in
            guard enabled else { return }
            handler()
        }
        action.isEnabled = enabled

        if let buttonColor = color(from: dict["color"]) {
            action.setValue(buttonColor, forKey: "titleTextColor")
        }

        return action
    }

    private static func alertStyle(
        from code: Int?,
        fallback: UIAlertAction.Style
    ) -> UIAlertAction.Style {
        switch code {
        case 1: return .cancel
        case 2: return .destructive
        default: return fallback
        }
    }

    private static func color(from value: Any?) -> UIColor? {
        guard let value else { return nil }
        if let argb = value as? Int64 {
            return IosGlassEffectFactory.uiColor(fromArgb: argb)
        }
        if let argb = value as? Int {
            return IosGlassEffectFactory.uiColor(fromArgb: Int64(argb))
        }
        if let number = value as? NSNumber {
            return IosGlassEffectFactory.uiColor(fromArgb: number.int64Value)
        }
        return nil
    }

    private static func applyLayoutDirection(to alert: UIAlertController, rtl: Bool) {
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        alert.view.semanticContentAttribute = attr
    }

    private static func applyAttributedText(
        to alert: UIAlertController,
        key: String,
        text: String,
        color: UIColor?,
        rtl: Bool
    ) {
        guard color != nil || rtl else { return }

        var attributes: [NSAttributedString.Key: Any] = [:]
        if let color {
            attributes[.foregroundColor] = color
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = rtl ? .right : .natural
        paragraph.baseWritingDirection = rtl ? .rightToLeft : .natural
        attributes[.paragraphStyle] = paragraph

        let attributed = NSAttributedString(string: text, attributes: attributes)
        alert.setValue(attributed, forKey: key)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        guard let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first else {
            return nil
        }

        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private enum IosAlertBarrierDismissAssociatedKey {
    static var handler = "iosAlertBarrierDismissHandler"
}

private final class IosAlertBarrierDismissHandler: NSObject, UIGestureRecognizerDelegate {
    private weak var alert: UIAlertController?
    private var onDismiss: (() -> Void)?

    static func attach(to alert: UIAlertController, onDismiss: @escaping () -> Void) {
        let handler = IosAlertBarrierDismissHandler()
        handler.alert = alert
        handler.onDismiss = onDismiss
        objc_setAssociatedObject(
            alert,
            &IosAlertBarrierDismissAssociatedKey.handler,
            handler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        DispatchQueue.main.async {
            guard let backdrop = handler.backdropView(for: alert) else { return }
            let tap = UITapGestureRecognizer(
                target: handler,
                action: #selector(handler.handleTap(_:))
            )
            tap.cancelsTouchesInView = false
            tap.delegate = handler
            backdrop.addGestureRecognizer(tap)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let alert, let view = gesture.view else { return }
        let location = gesture.location(in: view)
        let alertFrame = alert.view.convert(alert.view.bounds, to: view)
        guard !alertFrame.contains(location) else { return }
        onDismiss?()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let alert, let view = gestureRecognizer.view else { return false }
        let location = touch.location(in: view)
        let alertFrame = alert.view.convert(alert.view.bounds, to: view)
        return !alertFrame.contains(location)
    }

    private func backdropView(for alert: UIAlertController) -> UIView? {
        var candidate: UIView? = alert.view
        while let view = candidate {
            if view.bounds.width >= UIScreen.main.bounds.width * 0.9,
               view.bounds.height >= UIScreen.main.bounds.height * 0.9 {
                return view
            }
            candidate = view.superview
        }
        return alert.view.superview?.superview
    }
}
