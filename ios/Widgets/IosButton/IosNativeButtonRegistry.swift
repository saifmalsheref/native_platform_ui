import Foundation

@available(iOS 15.0, *)
final class IosNativeButtonRegistry {
    static let shared = IosNativeButtonRegistry()

    private var buttons: [Int64: WeakRef] = [:]

    private final class WeakRef {
        weak var value: IosButtonPlatformView?
        init(_ value: IosButtonPlatformView) { self.value = value }
    }

    func register(viewId: Int64, view: IosButtonPlatformView) {
        buttons[viewId] = WeakRef(view)
    }

    func unregister(viewId: Int64) {
        buttons.removeValue(forKey: viewId)
    }

    func view(for viewId: Int64) -> IosButtonPlatformView? {
        buttons[viewId]?.value
    }
}
