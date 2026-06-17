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

    private static func argsTransitionId(_ args: [String: Any]) -> String {
        args["transitionId"] as? String ?? ""
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

        let rawActions = args["actions"] as? [[String: Any]] ?? []
        let items: [IosPopoverMenuItem] = rawActions.map { entry in
            IosPopoverMenuItem(
                title: entry["title"] as? String ?? "",
                systemImage: entry["systemImage"] as? String,
                isDestructive: entry["isDestructive"] as? Bool ?? false
            )
        }
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

