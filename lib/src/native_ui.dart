import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_platform_ui/native_platform_ui.dart';

/// Facade for native iOS UI widgets exposed by this package.
abstract final class NativeUi {
  static const MethodChannel _channel = MethodChannel('native_ui');

  /// `true` when running on iOS 26+ with liquid glass (`UIGlassEffect`) available.
  static Future<bool> isIOS26AndAbove() async {
    if (!isNativeUiSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isIOS26AndAbove');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Widget button({
    Key? key,
    Widget? child,
    SfSymbols? sfSymbol,
    String? title,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    List<IosPopoverAction>? actions,
    ValueChanged<int>? onPopoverSelected,
    List<IosLinkedButtonItem>? linkedButtons,
    IosLinkedButtonsAxis linkedButtonsAxis = IosLinkedButtonsAxis.row,
    IosButtonOptions? options,
  }) {
    final opts = options ?? const IosButtonOptions();
    return IosButton(
      key: key,
      sfSymbol: sfSymbol,
      title: title,
      onPressed: onPressed,
      onLongPress: onLongPress,
      actions: actions,
      onPopoverSelected: onPopoverSelected,
      linkedButtons: linkedButtons,
      linkedButtonsAxis: linkedButtonsAxis == IosLinkedButtonsAxis.row
          ? opts.linkedButtonsAxis
          : linkedButtonsAxis,
      enabled: opts.enabled,
      cornerRadius: opts.cornerRadius,
      blurMaterial: opts.blurMaterial,
      interactive: opts.interactive,
      tintColor: opts.tintColor,
      materialBrightness: opts.materialBrightness,
      iconColor: opts.iconColor,
      iconSize: opts.iconSize,
      width: opts.width,
      height: opts.height,
      disabledOpacity: opts.disabledOpacity,
      popoverLink: opts.popoverLink,
      glass: opts.glass,
      glassUnion: opts.glassUnion,
      glassContainer: opts.glassContainer,
      padding: opts.padding,
      child: child,
    );
  }

  static Widget switchWidget({
    Key? key,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    Brightness? materialBrightness,
    Color? onTintColor,
    Color? thumbTintColor,
    Color? offTrackTintColor,
  }) {
    return IosSwitch(
      key: key,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      materialBrightness: materialBrightness,
      onTintColor: onTintColor,
      thumbTintColor: thumbTintColor,
      offTrackTintColor: offTrackTintColor,
    );
  }

  static Widget sfSymbol(
    SfSymbols symbol, {
    Key? key,
    Color? color,
    double size = 24,
  }) {
    return SfSymbolsWidget(
      key: key,
      symbol: symbol,
      color: color,
      size: size,
    );
  }

  static Widget glassContainer({
    Key? key,
    required Widget child,
    double cornerRadius = 16,
    bool interactive = false,
    Color? tintColor,
    Brightness? materialBrightness,
    IosNativeBlurMaterial blurMaterial = IosNativeBlurMaterial.liquidGlass,
    IosGlassHierarchy glassHierarchy = IosGlassHierarchy.primary,
    double? width,
    double? height,
    double? maxHeight,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    bool isCircle = false,
    Color? backgroundColor,
  }) {
    return PlatformContainer(
      key: key,
      cornerRadius: cornerRadius,
      interactive: interactive,
      tintColor: tintColor,
      materialBrightness: materialBrightness,
      blurMaterial: blurMaterial,
      glassHierarchy: glassHierarchy,
      width: width,
      height: height,
      maxHeight: maxHeight,
      maxWidth: maxWidth,
      padding: padding,
      isCircle: isCircle,
      backgroundColor: backgroundColor,
      child: child,
    );
  }

  static Widget bottomNavigationBar({
    Key? key,
    required List<IOSNavItem> items,
    int selectedIndex = 0,
    ValueChanged<int>? onChanged,
    Color? tintColor,
    Color? unselectedTintColor,
    Brightness? materialBrightness,
    double height = 60,
    double? iconSize,
    double? activeIconSize,
  }) {
    return NativeIOSBottomNavigationBar(
      key: key,
      items: items,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      tintColor: tintColor,
      unselectedTintColor: unselectedTintColor,
      materialBrightness: materialBrightness,
      height: height,
      iconSize: iconSize,
      activeIconSize: activeIconSize,
    );
  }

  static IosPopoverLink popoverLink({
    String? transitionId,
    double cornerRadius = 22.5,
  }) {
    return IosPopoverLink(
      transitionId: transitionId,
      cornerRadius: cornerRadius,
    );
  }
}

/// Options for [NativeUi.button].
class IosButtonOptions {
  const IosButtonOptions({
    this.enabled = true,
    this.cornerRadius = 22.5,
    this.blurMaterial = IosNativeBlurMaterial.liquidGlass,
    this.interactive = true,
    this.tintColor,
    this.materialBrightness,
    this.iconColor,
    this.iconSize = 22,
    this.width,
    this.height,
    this.disabledOpacity = 0.45,
    this.popoverLink,
    this.glass,
    this.glassUnion,
    this.glassContainer,
    this.linkedButtonsAxis = IosLinkedButtonsAxis.row,
    this.padding,
  });

  final bool enabled;
  final double cornerRadius;
  final IosNativeBlurMaterial blurMaterial;
  final bool interactive;
  final Color? tintColor;
  final Brightness? materialBrightness;
  final Color? iconColor;
  final double iconSize;
  final double? width;
  final double? height;
  final double disabledOpacity;
  final IosPopoverLink? popoverLink;
  final IosGlassOptions? glass;
  final IosGlassUnion? glassUnion;
  final IosGlassContainerOptions? glassContainer;
  final IosLinkedButtonsAxis linkedButtonsAxis;
  final EdgeInsetsGeometry? padding;
}
