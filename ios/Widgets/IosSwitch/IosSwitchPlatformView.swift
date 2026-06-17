import Flutter
import UIKit

final class IosSwitchPlatformView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let container: UIView
    private let uiSwitch: UISwitch
    private var methodChannel: FlutterMethodChannel?
    private var suppressChangeEvent = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        container = UIView(frame: frame)
        uiSwitch = UISwitch(frame: .zero)
        super.init()
        container.backgroundColor = .clear
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(uiSwitch)
        NSLayoutConstraint.activate([
            uiSwitch.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            uiSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            uiSwitch.topAnchor.constraint(equalTo: container.topAnchor),
            uiSwitch.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        IosPlatformViewCompositor.shared.register(viewId: viewId, view: container)
        applyArgs(args)
        uiSwitch.addTarget(self, action: #selector(onValueChanged), for: .valueChanged)
        let channel = FlutterMethodChannel(
            name: "ios_native_switch_\(viewId)",
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
            case "getIntrinsicSize":
                let size = self.uiSwitch.intrinsicContentSize
                result([
                    "width": Double(size.width),
                    "height": Double(size.height),
                ])
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
        container
    }

    @objc private func onValueChanged() {
        if suppressChangeEvent {
            return
        }
        methodChannel?.invokeMethod("valueChanged", arguments: ["value": uiSwitch.isOn])
    }

    private func applyArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }
        suppressChangeEvent = true
        defer { suppressChangeEvent = false }
        if let v = dict["value"] as? Bool {
            uiSwitch.setOn(v, animated: false)
        }
        if let e = dict["enabled"] as? Bool {
            uiSwitch.isEnabled = e
        }
        if let rtl = dict["layoutRtl"] as? Bool {
            let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            container.semanticContentAttribute = attr
            uiSwitch.semanticContentAttribute = attr
        }
        if dict.keys.contains("onTintArgb") {
            if let n = dict["onTintArgb"] as? NSNumber {
                let v = n.int64Value
                if v < 0 {
                    uiSwitch.onTintColor = nil
                } else {
                    uiSwitch.onTintColor = Self.uiColor(fromArgb: v)
                }
            }
        }
        if dict.keys.contains("thumbTintArgb") {
            if let n = dict["thumbTintArgb"] as? NSNumber {
                let v = n.int64Value
                if v < 0 {
                    uiSwitch.thumbTintColor = nil
                } else {
                    uiSwitch.thumbTintColor = Self.uiColor(fromArgb: v)
                }
            }
        }
        if dict.keys.contains("offTrackTintArgb") {
            if let n = dict["offTrackTintArgb"] as? NSNumber {
                let v = n.int64Value
                if v < 0 {
                    uiSwitch.tintColor = nil
                } else {
                    uiSwitch.tintColor = Self.uiColor(fromArgb: v)
                }
            }
        }
        let materialBrightness: Int = {
            if let v = dict["materialBrightness"] as? Int { return v }
            if let n = dict["materialBrightness"] as? NSNumber { return n.intValue }
            return -1
        }()
        let style: UIUserInterfaceStyle
        switch materialBrightness {
        case 0:
            style = .light
        case 1:
            style = .dark
        default:
            style = .unspecified
        }
        container.overrideUserInterfaceStyle = style
    }

    private static func uiColor(fromArgb argb: Int64) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xff) / 255.0
        let r = CGFloat((argb >> 16) & 0xff) / 255.0
        let g = CGFloat((argb >> 8) & 0xff) / 255.0
        let b = CGFloat(argb & 0xff) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
