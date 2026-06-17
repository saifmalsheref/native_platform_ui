import 'package:flutter/material.dart';

import 'options/glass_options.dart';

export 'options/glass_options.dart';

/// Native `UIBlurEffect` material tier (and optional liquid glass). Values are
/// stable across versions and map 1:1 to the iOS embedder.
enum IosNativeBlurMaterial {
  /// `UIBlurEffect(style: .systemUltraThinMaterial)` — lightest frost.
  ultraThin(0),

  /// `systemThinMaterial`
  thin(1),

  /// `systemMaterial`
  regular(2),

  /// `systemThickMaterial`
  thick(3),

  /// `systemChromeMaterial`
  chrome(4),

  /// iOS 26+ `UIGlassEffect` when available; otherwise falls back to [thin].
  liquidGlass(5);

  const IosNativeBlurMaterial(this.nativeCodec);

  /// Sent to the platform view; must match `LiquidGlassMaterialPlatformView.swift`.
  final int nativeCodec;
}

enum IosLiquidGlassBgColor {
  black,
  grey,
  adaptiveColor,
  transparent;

  Color colorFor(Brightness brightness) => switch (this) {
    IosLiquidGlassBgColor.adaptiveColor =>
      brightness == Brightness.dark
          ? IosLiquidGlassBgColor.black.colorFor(brightness)
          : Colors.transparent,
    IosLiquidGlassBgColor.black => Colors.black.withValues(alpha: 0.4),
    IosLiquidGlassBgColor.grey => Colors.grey.withValues(alpha: 0.2),
    IosLiquidGlassBgColor.transparent => Colors.transparent,
  };

  /// Flutter-side fill behind the native blur. [IosGlassHierarchy.nested] uses
  /// lower alpha so grouped tiles stay closer to Control Center (less mud).
  Color fillForGlass(IosGlassHierarchy hierarchy, Brightness brightness) {
    if (hierarchy == IosGlassHierarchy.nested) {
      return switch (this) {
        IosLiquidGlassBgColor.adaptiveColor =>
          brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.transparent,
        IosLiquidGlassBgColor.black => Colors.black.withValues(alpha: 0.26),
        IosLiquidGlassBgColor.grey => Colors.grey.withValues(alpha: 0.08),
        IosLiquidGlassBgColor.transparent => Colors.transparent,
      };
    }
    return colorFor(brightness);
  }
}
