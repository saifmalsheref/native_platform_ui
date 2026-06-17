import Flutter
import UIKit

public class NativeUiPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()

    let channel = FlutterMethodChannel(name: "native_ui", binaryMessenger: messenger)
    let instance = NativeUiPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    registrar.register(
      NativeIOSBottomNavBarFactory(messenger: messenger),
      withId: "native_ios_bottom_nav_bar"
    )

    registrar.register(
      SfSymbolsPlatformViewFactory(messenger: messenger),
      withId: "sf_symbols_view"
    )

    registrar.register(
      LiquidGlassMaterialPlatformViewFactory(messenger: messenger),
      withId: "liquid_glass_material_view"
    )

    registrar.register(
      IosSwitchPlatformViewFactory(messenger: messenger),
      withId: "ios_native_switch"
    )

    if #available(iOS 15.0, *) {
      registrar.register(
        IosButtonPlatformViewFactory(messenger: messenger),
        withId: "ios_native_button"
      )

      registrar.register(
        IosLinkedButtonsPlatformViewFactory(messenger: messenger),
        withId: "ios_native_linked_buttons"
      )

      IosPopoverHandler.register(messenger: messenger)
    }

    IosPlatformViewCompositor.register(messenger: messenger)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "isIOS26AndAbove":
      if #available(iOS 26.0, *) {
        result(NSClassFromString("UIGlassEffect") != nil)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
