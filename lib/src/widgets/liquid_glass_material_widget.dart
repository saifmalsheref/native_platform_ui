import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_platform_ui/src/ios_helper.dart';
import 'package:native_platform_ui/src/options/glass_options.dart';
import 'package:native_platform_ui/src/platform.dart';

/// Native blur / Liquid Glass on **iOS only** (`UiKitView`).
/// Updates after mount go through the method channel; [creationParams] stay frozen
/// so the platform view is not recreated on every parent rebuild.
/// Other platforms use a simple tinted surface (no `UiKitView`).
class PlatformContainer extends StatelessWidget {
  const PlatformContainer({
    super.key,
    required this.child,
    this.cornerRadius = 16,
    this.interactive = false,
    this.glassInteraction,
    this.tintColor,
    this.materialBrightness,
    this.blurMaterial = IosNativeBlurMaterial.liquidGlass,
    this.width,
    this.height,
    this.maxHeight,
    this.maxWidth,
    this.padding,
    this.isCircle = false,
    this.backgroundColor,
    this.backgroundColorType,
    this.glassHierarchy = IosGlassHierarchy.primary,
    this.glass,
    this.glassUnion,
    this.glassContainer,
    this.allowAppleStyle = true,
  });
  final bool allowAppleStyle;
  final Widget child;
  final double cornerRadius;
  final bool interactive;

  /// Fine-grained liquid-glass touch feedback. When null, derived from [interactive].
  final IosGlassInteraction? glassInteraction;
  final Color? tintColor;
  final Brightness? materialBrightness;
  final IosNativeBlurMaterial blurMaterial;
  final IosGlassHierarchy glassHierarchy;
  final IosGlassOptions? glass;
  final IosGlassUnion? glassUnion;
  final IosGlassContainerOptions? glassContainer;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double? maxHeight;
  final double? maxWidth;
  final bool isCircle;
  final Color? backgroundColor;
  final IosLiquidGlassBgColor? backgroundColorType;

  @override
  Widget build(BuildContext context) {
    if (allowAppleStyle && isNativeUiSupported) {
      return _IosContainer(
        cornerRadius: cornerRadius,
        interactive: interactive,
        glassInteraction: glassInteraction,
        tintColor: tintColor,
        materialBrightness: materialBrightness,
        blurMaterial: blurMaterial,
        glassHierarchy: glassHierarchy,
        glass: glass,
        glassUnion: glassUnion,
        glassContainer: glassContainer,
        allowAppleStyle: allowAppleStyle,
        width: width,
        height: height,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
        padding: padding,
        isCircle: isCircle,
        backgroundColor: backgroundColor,
        backgroundColorType: backgroundColorType,
        child: child,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tintColor,
        borderRadius: isCircle ? null : BorderRadius.circular(cornerRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}

class _IosContainer extends StatefulWidget {
  const _IosContainer({
    required this.child,
    this.cornerRadius = 16,
    this.interactive = false,
    this.glassInteraction,
    this.tintColor,
    this.materialBrightness,
    this.blurMaterial = IosNativeBlurMaterial.liquidGlass,
    this.width,
    this.height,
    this.maxHeight,
    this.maxWidth,
    this.padding,
    this.isCircle = false,
    this.backgroundColor,
    this.backgroundColorType,
    this.glassHierarchy = IosGlassHierarchy.primary,
    this.glass,
    this.glassUnion,
    this.glassContainer,
    this.allowAppleStyle = true,
  });

  final Widget child;
  final double cornerRadius;
  final bool interactive;
  final IosGlassInteraction? glassInteraction;
  final Color? tintColor, backgroundColor;
  final IosLiquidGlassBgColor? backgroundColorType;

  /// When null, uses [Theme.of] for this subtree. When set, forces that brightness
  /// on the native view (`overrideUserInterfaceStyle`).
  final Brightness? materialBrightness;

  /// Native blur strength / material style ([IosNativeBlurMaterial.nativeCodec]).
  final IosNativeBlurMaterial blurMaterial;
  final double? width, height;
  final double? maxHeight, maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool isCircle;

  /// [IosGlassHierarchy.nested] maps to lighter UIKit materials on iOS (see Swift).
  final IosGlassHierarchy glassHierarchy;
  final IosGlassOptions? glass;
  final IosGlassUnion? glassUnion;
  final IosGlassContainerOptions? glassContainer;

  /// When false on iOS, skips [UiKitView] / liquid glass and uses the same tinted
  /// or solid path as other platforms.
  final bool allowAppleStyle;

  @override
  State<_IosContainer> createState() => _IosContainerState();
}

class _IosContainerState extends State<_IosContainer> {
  static const String _viewType = 'liquid_glass_material_view';
  static const String _channelPrefix = 'liquid_glass_material_';
  static const int _kMaterialUnspecified = -1;
  MethodChannel? _channel;
  int? _lastNativeParamsFingerprint;
  double? _resolvedCornerRadius;

  double _effectiveCornerRadius(BoxConstraints constraints) {
    if (!widget.isCircle) {
      return widget.cornerRadius;
    }
    double side = 0;
    final width = widget.width;
    final height = widget.height;
    if (width != null && height != null) {
      side = math.min(width, height);
    } else if (constraints.hasBoundedWidth &&
        constraints.hasBoundedHeight &&
        constraints.maxWidth.isFinite &&
        constraints.maxHeight.isFinite) {
      side = math.min(constraints.maxWidth, constraints.maxHeight);
    } else if (width != null) {
      side = width;
    } else if (height != null) {
      side = height;
    }
    if (side > 0) {
      return side / 2;
    }
    return widget.cornerRadius;
  }

  Map<String, Object?>? _embedCreationParams;

  IosGlassOptions _resolvedGlassOptions({required double cornerRadius}) {
    return resolveIosGlassOptions(
      glass: widget.glass,
      cornerRadius: cornerRadius,
      isCircle: widget.isCircle,
      interactive: widget.interactive,
      glassInteraction: widget.glassInteraction,
      tintColor: widget.tintColor,
      materialBrightness: widget.materialBrightness,
      blurMaterial: widget.blurMaterial.nativeCodec,
      glassHierarchy: widget.glassHierarchy,
      union: widget.glassUnion,
      container: widget.glassContainer,
    );
  }

  static int _encodeMaterialBrightness(Brightness b) =>
      b == Brightness.light ? 0 : 1;

  int _materialCodecFor(BuildContext context) {
    final Brightness b =
        widget.materialBrightness ?? Theme.of(context).brightness;
    return _encodeMaterialBrightness(b);
  }

  void _flushNativeParamsIfNeeded(
    BuildContext context, {
    required double cornerRadius,
  }) {
    if (!isNativeUiSupported || !widget.allowAppleStyle) {
      return;
    }
    final MethodChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    final int material = _materialCodecFor(context);
    final IosGlassOptions options = _resolvedGlassOptions(
      cornerRadius: cornerRadius,
    );
    final int fp = options.fingerprint(
      cornerRadius: cornerRadius,
      interactiveFallback: widget.interactive,
      materialBrightnessCodec: material,
    );
    if (_lastNativeParamsFingerprint == fp) {
      return;
    }
    _lastNativeParamsFingerprint = fp;
    ch.invokeMethod<void>(
      'update',
      options.toNativeMap(
        cornerRadius: cornerRadius,
        interactiveFallback: widget.interactive,
        themeBrightness: Theme.of(context).brightness,
      )..['materialBrightness'] = material,
    );
  }

  Map<String, Object?> _nativeCreationParams({required double cornerRadius}) {
    final IosGlassOptions options = _resolvedGlassOptions(
      cornerRadius: cornerRadius,
    );
    return options.toNativeMap(
      cornerRadius: cornerRadius,
      interactiveFallback: widget.interactive,
    )..['materialBrightness'] = _kMaterialUnspecified;
  }

  void _notifyNativeTouchDown(Offset localPosition) {
    _channel?.invokeMethod<void>('touchDown', <String, Object?>{
      'x': localPosition.dx,
      'y': localPosition.dy,
    });
  }

  void _notifyNativeTouchUp() {
    _channel?.invokeMethod<void>('touchUp');
  }

  Widget _wrapTouchForwarding(Widget child) {
    final IosGlassInteraction interaction = _resolvedGlassOptions(
      cornerRadius: _resolvedCornerRadius ?? widget.cornerRadius,
    ).resolveInteraction(interactiveFallback: widget.interactive);
    if (!isNativeUiSupported || !widget.allowAppleStyle) {
      return child;
    }
    if (!interaction.pressScale && !interaction.pressGlow) {
      return child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        _notifyNativeTouchDown(event.localPosition);
      },
      onPointerUp: (_) => _notifyNativeTouchUp(),
      onPointerCancel: (_) => _notifyNativeTouchUp(),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    if (isNativeUiSupported && widget.allowAppleStyle) {
      final double initialRadius = widget.isCircle
          ? (widget.width != null && widget.height != null
                ? math.min(widget.width!, widget.height!) / 2
                : widget.cornerRadius)
          : widget.cornerRadius;
      _embedCreationParams = _nativeCreationParams(cornerRadius: initialRadius);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedCornerRadius != null) {
      _flushNativeParamsIfNeeded(context, cornerRadius: _resolvedCornerRadius!);
    }
  }

  @override
  void didUpdateWidget(_IosContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isNativeUiSupported) {
      return;
    }
    if (!widget.allowAppleStyle) {
      _channel = null;
      _lastNativeParamsFingerprint = null;
      return;
    }
    _embedCreationParams ??= _nativeCreationParams(
      cornerRadius: _resolvedCornerRadius ?? widget.cornerRadius,
    );
    final bool nativeChanged =
        oldWidget.allowAppleStyle != widget.allowAppleStyle ||
        oldWidget.cornerRadius != widget.cornerRadius ||
        oldWidget.isCircle != widget.isCircle ||
        oldWidget.interactive != widget.interactive ||
        oldWidget.glassInteraction != widget.glassInteraction ||
        oldWidget.tintColor != widget.tintColor ||
        oldWidget.materialBrightness != widget.materialBrightness ||
        oldWidget.blurMaterial != widget.blurMaterial ||
        oldWidget.glassHierarchy != widget.glassHierarchy ||
        oldWidget.glass != widget.glass ||
        oldWidget.glassUnion != widget.glassUnion ||
        oldWidget.glassContainer != widget.glassContainer;
    if (nativeChanged) {
      _lastNativeParamsFingerprint = null;
      if (_resolvedCornerRadius != null) {
        _flushNativeParamsIfNeeded(
          context,
          cornerRadius: _resolvedCornerRadius!,
        );
      }
    }
  }

  @override
  void dispose() {
    _channel = null;
    _lastNativeParamsFingerprint = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget layeredChild;
    if (isNativeUiSupported && widget.allowAppleStyle) {
      layeredChild = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: UiKitView(
                  viewType: _viewType,
                  creationParams: _embedCreationParams!,
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (int id) {
                    _channel = MethodChannel('$_channelPrefix$id');
                    _lastNativeParamsFingerprint = null;
                    if (mounted && _resolvedCornerRadius != null) {
                      _flushNativeParamsIfNeeded(
                        context,
                        cornerRadius: _resolvedCornerRadius!,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          RepaintBoundary(child: widget.child),
        ],
      );
    } else {
      final Color? tint = widget.tintColor;
      if (tint != null) {
        final double tintRadius = _resolvedCornerRadius ?? widget.cornerRadius;
        layeredChild = Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    shape: widget.isCircle
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: widget.isCircle
                        ? null
                        : BorderRadius.circular(tintRadius),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      } else {
        layeredChild = widget.child;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = _effectiveCornerRadius(constraints);
        if (_resolvedCornerRadius != radius) {
          _resolvedCornerRadius = radius;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _flushNativeParamsIfNeeded(context, cornerRadius: radius);
            }
          });
        }

        final fillColor = (isNativeUiSupported && widget.allowAppleStyle)
            ? (widget.backgroundColorType?.fillForGlass(
                  widget.glassHierarchy,
                  Theme.of(context).brightness,
                ) ??
                widget.backgroundColor ??
                widget.tintColor)
            : widget.backgroundColor ?? widget.tintColor;

        final container = Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: fillColor,
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(radius),
          ),
          constraints: widget.maxWidth != null || widget.maxHeight != null
              ? BoxConstraints(
                  maxWidth: widget.maxWidth ?? double.infinity,
                  maxHeight: widget.maxHeight ?? double.infinity,
                )
              : null,
          padding: widget.padding,
          width: widget.width,
          height: widget.height,
          child: layeredChild,
        );

        if (widget.isCircle) {
          return ClipOval(
            clipBehavior: Clip.antiAlias,
            child: _wrapTouchForwarding(container),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: _wrapTouchForwarding(container),
        );
      },
    );
  }
}
