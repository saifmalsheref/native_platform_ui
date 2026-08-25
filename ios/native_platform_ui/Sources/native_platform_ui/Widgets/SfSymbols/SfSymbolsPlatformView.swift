import Flutter
import UIKit

private final class SfSymbolRootView: UIView {
    private let imageView = UIImageView()
    private var symbol: String = ""
    private var colorArgb: Int64?
    private var lastSymbol: String?
    private var lastColorArgb: Int64?
    private var lastLayoutPointSize: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(symbol: String, colorArgb: Int64?) {
        self.symbol = symbol
        self.colorArgb = colorArgb
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let w = bounds.width
        let h = bounds.height
        let pt = w > 0 && h > 0 ? min(w, h) : 0
        applyIfChanged(layoutPointSize: pt)
    }

    private func applyIfChanged(layoutPointSize: CGFloat) {
        if layoutPointSize < 1 {
            return
        }
        if symbol == lastSymbol,
           colorArgb == lastColorArgb,
           abs(layoutPointSize - lastLayoutPointSize) < 0.5 {
            return
        }
        lastSymbol = symbol
        lastColorArgb = colorArgb
        lastLayoutPointSize = layoutPointSize
        let config = UIImage.SymbolConfiguration(pointSize: layoutPointSize, weight: .regular)
        guard let image = UIImage(systemName: symbol, withConfiguration: config) else {
            imageView.image = nil
            return
        }
        if let argb = colorArgb {
            let a = CGFloat((argb >> 24) & 0xff) / 255.0
            let r = CGFloat((argb >> 16) & 0xff) / 255.0
            let g = CGFloat((argb >> 8) & 0xff) / 255.0
            let b = CGFloat(argb & 0xff) / 255.0
            imageView.tintColor = UIColor(red: r, green: g, blue: b, alpha: a)
            imageView.image = image.withRenderingMode(.alwaysTemplate)
        } else {
            imageView.tintColor = nil
            imageView.image = image.withRenderingMode(.automatic)
        }
    }
}

final class SfSymbolsPlatformView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let rootView: SfSymbolRootView
    private var methodChannel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        rootView = SfSymbolRootView(frame: frame)
        super.init()
        IosPlatformViewCompositor.shared.register(
            viewId: viewId,
            view: rootView,
            policy: .none
        )
        applyArgs(args)
        let channel = FlutterMethodChannel(name: "sf_symbols_\(viewId)", binaryMessenger: messenger)
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

    private func applyArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }
        let symbol = dict["symbol"] as? String ?? ""
        let colorArgb: Int64? = {
            if let v = dict["color"] as? Int64 { return v }
            if let v = dict["color"] as? Int { return Int64(v) }
            if let n = dict["color"] as? NSNumber { return n.int64Value }
            return nil
        }()
        rootView.configure(symbol: symbol, colorArgb: colorArgb)
    }
}
