/// Platform view IDs registered in [ios/Widgets] via [NativeUiPlugin].
abstract final class NativeUiPlatformViews {
  /// [ios/Widgets/IosButton]
  static const String iosButton = 'ios_native_button';
  static const String iosButtonChannel = 'ios_native_button_';
  static const String iosLinkedButtons = 'ios_native_linked_buttons';
  static const String iosLinkedButtonsChannel = 'ios_native_linked_buttons_';

  /// [ios/Widgets/IosSwitch]
  static const String iosSwitch = 'ios_native_switch';
  static const String iosSwitchChannel = 'ios_native_switch_';

  /// [ios/Widgets/SfSymbols]
  static const String sfSymbols = 'sf_symbols_view';
  static const String sfSymbolsChannel = 'sf_symbols_';

  /// [ios/Widgets/LiquidGlassMaterial]
  static const String liquidGlassMaterial = 'liquid_glass_material_view';
  static const String liquidGlassMaterialChannel = 'liquid_glass_material_';

  /// [ios/Widgets/NativeIOSBottomNavBar]
  static const String bottomNavBar = 'native_ios_bottom_nav_bar';
  static const String bottomNavBarChannel = 'native_ios_bottom_nav_bar_';

  /// [ios/Widgets/IosPopover]
  static const String popover = 'ios_native_popover';
  static const String popoverEvents = 'ios_native_popover_events';

  /// [ios/Widgets/IosPlatformViewCompositor]
  static const String platformViewOverlay = 'ios_platform_view_overlay';
}
