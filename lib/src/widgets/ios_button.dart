import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_ui/native_ui.dart';

/// One segment in a native linked [IosButton] group (SwiftUI `ControlGroup`).
class IosLinkedButtonItem {
  const IosLinkedButtonItem({
    this.sfSymbol,
    this.title,
    this.onPressed,
    this.enabled = true,
    this.iconColor,
    this.iconSize,
  });

  final String? sfSymbol;
  final String? title;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? iconColor;
  final double? iconSize;

  Map<String, Object?> encode({
    required Color defaultIconColor,
    required double defaultIconSize,
  }) => <String, Object?>{
    'sfSymbol': sfSymbol,
    'title': title,
    'enabled': enabled && onPressed != null,
    'iconColor': (iconColor ?? defaultIconColor).toARGB32(),
    'iconSize': iconSize ?? defaultIconSize,
  };
}

/// Native `UIButton` on iOS ([UiKitView]) with liquid-glass chrome (`UIGlassEffect`
/// on iOS 26 when available). [onPressed] / [onLongPress] are handled in UIKit.
///
/// When [linkedButtons] is non-null, renders a native linked control group
/// (SwiftUI `ControlGroup` + `.controlGroupStyle(.navigation)`).
class IosButton extends StatefulWidget {
  const IosButton({
    super.key,
    this.child,
    this.sfSymbol,
    this.title,
    this.onPressed,
    this.onLongPress,
    this.actions,
    this.onPopoverSelected,
    this.enabled = true,
    this.cornerRadius = 22.5,
    this.blurMaterial = IosNativeBlurMaterial.liquidGlass,
    this.interactive = true,
    this.glassInteraction,
    this.tintColor,
    this.materialBrightness,
    this.iconColor,
    this.iconSize = 22,
    this.width = 45,
    this.height = 45,
    this.disabledOpacity = 0.45,
    this.popoverLink,
    this.linkedButtons,
    this.glass,
    this.glassUnion,
    this.glassContainer,
  }) : assert(
         linkedButtons == null || linkedButtons.length >= 2,
         'linkedButtons requires at least 2 items',
       );

  final Widget? child;
  final SfSymbols? sfSymbol;
  final String? title;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final List<IosPopoverAction>? actions;
  final ValueChanged<int>? onPopoverSelected;
  final bool enabled;

  final double cornerRadius;
  final IosNativeBlurMaterial blurMaterial;
  final bool interactive;

  /// Fine-grained liquid-glass touch feedback. When null, derived from [interactive].
  final IosGlassInteraction? glassInteraction;
  final Color? tintColor;
  final Brightness? materialBrightness;
  final Color? iconColor;
  final double iconSize;
  final double? width;
  final double? height;
  final double disabledOpacity;

  final IosPopoverLink? popoverLink;

  /// When set, renders a native linked button row instead of a single button.
  final List<IosLinkedButtonItem>? linkedButtons;

  /// Unified glass config; overrides [blurMaterial], [tintColor], etc. when set.
  final IosGlassOptions? glass;
  final IosGlassUnion? glassUnion;
  final IosGlassContainerOptions? glassContainer;

  bool get _isLinkedGroup =>
      linkedButtons != null && linkedButtons!.length >= 2;

  @override
  State<IosButton> createState() => _IosButtonState();
}

class _IosButtonState extends State<IosButton> {
  Color get color =>
      widget.iconColor ??
      (Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black);
  static const String _viewType = 'ios_native_button';
  static const String _linkedViewType = 'ios_native_linked_buttons';
  static const String _channelPrefix = 'ios_native_button_';
  static const String _linkedChannelPrefix = 'ios_native_linked_buttons_';
  static const int _kMaterialUnspecified = -1;
  static const int _kColorUnset = -1;
  static const double _linkedSegmentHorizontalInset = 12;
  static const double _linkedSegmentCoreWidth = 24;
  static const double _linkedSegmentWidth =
      _linkedSegmentHorizontalInset * 2 + _linkedSegmentCoreWidth;
  static const double _defaultSide = 45;

  bool get _usesFlutterChild => widget.child != null;

  ({double? width, double height}) _resolveButtonSize() {
    final double? width = widget.width;
    final double? height = widget.height;

    if (height != null) {
      return (width: width, height: height);
    }
    if (width != null && width.isFinite) {
      return (width: width, height: width);
    }
    return (width: width, height: _defaultSide);
  }

  IosGlassOptions _resolvedGlassOptions() {
    return resolveIosGlassOptions(
      glass: widget.glass,
      cornerRadius: widget.cornerRadius,
      interactive: widget.interactive,
      glassInteraction: widget.glassInteraction,
      tintColor: widget.tintColor,
      materialBrightness: widget.materialBrightness,
      blurMaterial: widget.blurMaterial.nativeCodec,
      union: widget.glassUnion,
      container: widget.glassContainer,
    );
  }

  MethodChannel? _channel;
  Map<String, Object?>? _creationParams;
  int? _lastNativeFingerprint;

  static int _encodeMaterialBrightness(Brightness b) =>
      b == Brightness.light ? 0 : 1;

  int _materialCodecFor(BuildContext context) {
    final Brightness b =
        widget.materialBrightness ?? Theme.of(context).brightness;
    return _encodeMaterialBrightness(b);
  }

  Map<String, Object?> _sharedNativeParams(BuildContext context) {
    final IosGlassOptions options = _resolvedGlassOptions();
    return <String, Object?>{
      ...options.toNativeMap(
        cornerRadius: widget.cornerRadius,
        interactiveFallback: widget.interactive,
        themeBrightness: Theme.of(context).brightness,
      ),
      'materialBrightness': _materialCodecFor(context),
      'iconSize': widget.iconSize,
    };
  }

  Map<String, Object?> _nativeParams(BuildContext context) {
    return <String, Object?>{
      ..._sharedNativeParams(context),
      'enabled':
          widget.enabled &&
          (widget.onPressed != null || widget.actions != null),
      'hasLongPress': widget.onLongPress != null,
      'sfSymbol': _usesFlutterChild ? null : widget.sfSymbol?.value,
      'title': _usesFlutterChild ? null : widget.title,
      'iconColor': color.toARGB32(),
      'popoverTransitionId': widget.popoverLink?.transitionId,
      'popoverActions': widget.actions
          ?.map((IosPopoverAction e) => e.encode())
          .toList(),
    };
  }

  Map<String, Object?> _linkedNativeParams(BuildContext context) {
    final List<IosLinkedButtonItem> items = widget.linkedButtons!;
    return <String, Object?>{
      ..._sharedNativeParams(context),
      'linkedButtons': items
          .map(
            (IosLinkedButtonItem e) => e.encode(
              defaultIconColor: color,
              defaultIconSize: widget.iconSize,
            ),
          )
          .toList(),
    };
  }

  int _paramsFingerprint(BuildContext context) {
    final IosGlassOptions options = _resolvedGlassOptions();
    final int glassFp = options.fingerprint(
      cornerRadius: widget.cornerRadius,
      interactiveFallback: widget.interactive,
      materialBrightnessCodec: _materialCodecFor(context),
    );
    if (widget._isLinkedGroup) {
      final p = _linkedNativeParams(context);
      return Object.hash(glassFp, Object.hashAll(p['linkedButtons'] as List));
    }
    final p = _nativeParams(context);
    return Object.hash(
      glassFp,
      p['enabled'],
      p['hasLongPress'],
      p['sfSymbol'],
      p['title'],
      p['iconColor'],
      p['iconSize'],
      p['popoverTransitionId'],
      Object.hashAll(p['popoverActions'] as List? ?? []),
    );
  }

  void _flushNativeParamsIfNeeded(BuildContext context) {
    if (!isNativeUiSupported) {
      return;
    }
    final MethodChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    final int fp = _paramsFingerprint(context);
    if (_lastNativeFingerprint == fp) {
      return;
    }
    _lastNativeFingerprint = fp;
    ch.invokeMethod<void>(
      'update',
      widget._isLinkedGroup
          ? _linkedNativeParams(context)
          : _nativeParams(context),
    );
  }

  Map<String, Object?> _initialNativeParams() {
    final IosGlassOptions options = _resolvedGlassOptions();
    return <String, Object?>{
      ...options.toNativeMap(
        cornerRadius: widget.cornerRadius,
        interactiveFallback: widget.interactive,
      )..['materialBrightness'] = _kMaterialUnspecified,
      'enabled':
          widget.enabled &&
          (widget.onPressed != null || widget.actions != null),
      'hasLongPress': widget.onLongPress != null,
      'sfSymbol': _usesFlutterChild ? null : widget.sfSymbol?.value,
      'title': _usesFlutterChild ? null : widget.title,
      'iconColor': widget.iconColor?.toARGB32() ?? _kColorUnset,
      'iconSize': widget.iconSize,
      'popoverTransitionId': widget.popoverLink?.transitionId,
      'popoverActions': widget.actions
          ?.map((IosPopoverAction e) => e.encode())
          .toList(),
    };
  }

  Map<String, Object?> _initialLinkedNativeParams() {
    final List<IosLinkedButtonItem> items = widget.linkedButtons!;
    final IosGlassOptions options = _resolvedGlassOptions();
    return <String, Object?>{
      ...options.toNativeMap(
        cornerRadius: widget.cornerRadius,
        interactiveFallback: widget.interactive,
      )..['materialBrightness'] = _kMaterialUnspecified,
      'iconSize': widget.iconSize,
      'linkedButtons': items
          .map(
            (IosLinkedButtonItem e) => e.encode(
              defaultIconColor:
                  widget.iconColor ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
              defaultIconSize: widget.iconSize,
            ),
          )
          .toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    if (isNativeUiSupported) {
      _creationParams = widget._isLinkedGroup
          ? _initialLinkedNativeParams()
          : _initialNativeParams();
    }
  }

  @override
  void didUpdateWidget(IosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _flushNativeParamsIfNeeded(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flushNativeParamsIfNeeded(context);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  Future<void> _onPlatformMessage(MethodCall call) async {
    switch (call.method) {
      case 'pressed':
        if (widget.enabled) {
          widget.onPressed?.call();
        }
      case 'longPressed':
        if (widget.enabled) {
          widget.onLongPress?.call();
        }
      case 'popoverSelected':
        final Object? raw = call.arguments;
        if (widget.enabled && raw is int) {
          widget.onPopoverSelected?.call(raw);
        } else if (widget.enabled && raw is num) {
          widget.onPopoverSelected?.call(raw.toInt());
        }
      case 'linkedButtonPressed':
        final Object? raw = call.arguments;
        final List<IosLinkedButtonItem>? items = widget.linkedButtons;
        if (items == null) {
          return;
        }
        final int? index = raw is int ? raw : (raw is num ? raw.toInt() : null);
        if (index == null || index < 0 || index >= items.length) {
          return;
        }
        final IosLinkedButtonItem item = items[index];
        if (item.enabled) {
          item.onPressed?.call();
        }
    }
  }

  Widget _fallbackButton(BuildContext context) {
    if (widget._isLinkedGroup) {
      return _fallbackLinkedGroup(context);
    }

    final bool hasPopover =
        widget.actions != null && widget.actions!.isNotEmpty;
    final bool canTap =
        widget.enabled && (widget.onPressed != null || hasPopover);

    final Widget label =
        widget.child ??
        (widget.title != null
            ? Text(widget.title!)
            : Icon(Icons.add, size: widget.iconSize, color: widget.iconColor));

    return Opacity(
      opacity: canTap ? 1.0 : widget.disabledOpacity,
      child: Material(
        color: widget.tintColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.cornerRadius),
        child: InkWell(
          onTap: canTap && !hasPopover ? widget.onPressed : null,
          onLongPress: canTap ? widget.onLongPress : null,
          borderRadius: BorderRadius.circular(widget.cornerRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Center(child: label),
          ),
        ),
      ),
    );
  }

  Widget _fallbackLinkedGroup(BuildContext context) {
    final items = widget.linkedButtons!;
    return Material(
      color: widget.tintColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++)
            InkWell(
              onTap: items[i].enabled ? items[i].onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _linkedSegmentHorizontalInset,
                ),
                child: SizedBox(
                  width: _linkedSegmentCoreWidth,
                  height: widget.height ?? 36,
                  child: Center(
                    child: items[i].sfSymbol != null
                        ? Icon(
                            Icons.circle,
                            size: widget.iconSize,
                            color: color,
                          )
                        : Text(items[i].title ?? ''),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double? get _linkedGroupWidth {
    final int count = widget.linkedButtons?.length ?? 0;
    if (count < 2) {
      return null;
    }
    return count * _linkedSegmentWidth;
  }

  @override
  Widget build(BuildContext context) {
    if (widget._isLinkedGroup) {
      return _buildLinkedGroup(context);
    }
    return _buildSingleButton(context);
  }

  Widget _buildLinkedGroup(BuildContext context) {
    if (!isNativeUiSupported) {
      return SizedBox(
        width: widget.width ?? _linkedGroupWidth,
        height: widget.height ?? 36,
        child: _fallbackLinkedGroup(context),
      );
    }

    return SizedBox(
      width: widget.width ?? _linkedGroupWidth,
      height: widget.height ?? 36,
      child: UiKitView(
        viewType: _linkedViewType,
        creationParams: _creationParams!,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) {
          _channel = MethodChannel('$_linkedChannelPrefix$id')
            ..setMethodCallHandler((MethodCall call) async {
              await _onPlatformMessage(call);
            });
          _lastNativeFingerprint = _paramsFingerprint(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _flushNativeParamsIfNeeded(context);
            }
          });
        },
      ),
    );
  }

  Widget _buildNativeUiKitButton(BuildContext context) {
    return UiKitView(
      viewType: _viewType,
      creationParams: _creationParams!,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        widget.popoverLink?.nativeButtonViewId = id;
        _channel = MethodChannel('$_channelPrefix$id')
          ..setMethodCallHandler((MethodCall call) async {
            await _onPlatformMessage(call);
          });
        _lastNativeFingerprint = _paramsFingerprint(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _flushNativeParamsIfNeeded(context);
          }
        });
      },
    );
  }

  Widget _wrapNativeButton(BuildContext context, Widget native) {
    final IosPopoverLink? link = widget.popoverLink;
    if (link == null) {
      return native;
    }
    return KeyedSubtree(key: link.anchorKey, child: native);
  }

  Widget _buildChildOverlayButton(BuildContext context) {
    final ({double? width, double height}) size = _resolveButtonSize();

    if (!isNativeUiSupported) {
      return SizedBox(
        width: size.width,
        height: size.height,
        child: _fallbackButton(context),
      );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: _wrapNativeButton(
        context,
        Stack(
          fit: StackFit.expand,
          children: [
            _buildNativeUiKitButton(context),
            Positioned.fill(child: IgnorePointer(child: widget.child!)),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleButton(BuildContext context) {
    if (_usesFlutterChild) {
      return _buildChildOverlayButton(context);
    }

    final ({double? width, double height}) size = _resolveButtonSize();

    if (!isNativeUiSupported) {
      return SizedBox(
        width: size.width,
        height: size.height,
        child: _fallbackButton(context),
      );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: _wrapNativeButton(context, _buildNativeUiKitButton(context)),
    );
  }
}
