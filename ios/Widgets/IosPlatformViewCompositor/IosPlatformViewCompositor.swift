import Flutter
import UIKit

/// How an embedded platform view should behave when Flutter modal overlays animate.
public enum IosPlatformViewCompositionPolicy {
    /// Do not alter the view (UITabBar, liquid glass, etc.).
    case none
    /// Clip and disable group opacity only — safe for animated/blurred UIKit controls.
    case stabilizeOnOverlay
}

/// Stabilizes embedded platform views when Flutter modal overlays animate above them.
///
/// `shouldRasterize` must not be used on UITabBar or blur-backed views; it causes the
/// milky trails / ghost selection pill seen when switching tabs after a sheet closes.
public final class IosPlatformViewCompositor {
    public static let shared = IosPlatformViewCompositor()

    private struct Entry {
        weak var view: UIView?
        let policy: IosPlatformViewCompositionPolicy
        var savedAllowsGroupOpacity: Bool?
    }

    private var entries: [Int64: Entry] = [:]
    private var overlayActive = false
    /// Views registered after the overlay opened (e.g. SF Symbols inside a bottom sheet)
    /// must not be stabilized — that breaks their tint/opacity rendering.
    private var stabilizedViewIds: Set<Int64> = []

    private init() {}

    public static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "ios_platform_view_overlay",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setOverlayActive":
                let active = (call.arguments as? [String: Any])?["active"] as? Bool ?? false
                shared.setOverlayActive(active)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    public func register(
        viewId: Int64,
        view: UIView,
        policy: IosPlatformViewCompositionPolicy = .stabilizeOnOverlay
    ) {
        var entry = Entry(view: view, policy: policy)
        if policy != .none {
            view.clipsToBounds = true
            view.layer.masksToBounds = true
        }
        entries[viewId] = entry
    }

    public func unregister(viewId: Int64) {
        if stabilizedViewIds.contains(viewId),
           var entry = entries[viewId],
           let view = entry.view {
            restoreOverlayComposition(on: view, entry: &entry)
            entries[viewId] = entry
        }
        stabilizedViewIds.remove(viewId)
        entries.removeValue(forKey: viewId)
    }

    func setOverlayActive(_ active: Bool) {
        guard overlayActive != active else { return }
        overlayActive = active

        if active {
            stabilizedViewIds = Set(
                entries.compactMap { viewId, entry in
                    entry.policy == .stabilizeOnOverlay ? viewId : nil
                }
            )
            for viewId in stabilizedViewIds {
                guard var entry = entries[viewId], let view = entry.view else {
                    continue
                }
                applyOverlayComposition(to: view, entry: &entry)
                entries[viewId] = entry
            }
            return
        }

        for viewId in stabilizedViewIds {
            guard var entry = entries[viewId], let view = entry.view else {
                continue
            }
            restoreOverlayComposition(on: view, entry: &entry)
            entries[viewId] = entry
        }
        stabilizedViewIds.removeAll()
    }

    private func applyOverlayComposition(to view: UIView, entry: inout Entry) {
        let layer = view.layer
        if entry.savedAllowsGroupOpacity == nil {
            entry.savedAllowsGroupOpacity = layer.allowsGroupOpacity
        }
        layer.allowsGroupOpacity = false
        layer.masksToBounds = true
        view.clipsToBounds = true
    }

    private func restoreOverlayComposition(on view: UIView, entry: inout Entry) {
        let layer = view.layer
        if let saved = entry.savedAllowsGroupOpacity {
            layer.allowsGroupOpacity = saved
        }
        entry.savedAllowsGroupOpacity = nil
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
