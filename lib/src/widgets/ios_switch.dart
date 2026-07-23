import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_platform_ui/src/platform.dart';

/// Native `UISwitch` on iOS ([UiKitView]); [Switch] on other platforms.
class IosSwitch extends StatefulWidget {
  const IosSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.materialBrightness,
    this.layoutRtl,
    this.onTintColor,
    this.thumbTintColor,
    this.offTrackTintColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Brightness? materialBrightness;
  final bool? layoutRtl;
  final Color? onTintColor;
  final Color? thumbTintColor;
  final Color? offTrackTintColor;

  @override
  State<IosSwitch> createState() => _IosSwitchState();
}

class _IosSwitchState extends State<IosSwitch> {
  static const String _viewType = 'ios_native_switch';
  static const String _channelPrefix = 'ios_native_switch_';
  static const int _kMaterialUnspecified = -1;
  static const int _kNativeTintUnset = -1;

  MethodChannel? _channel;
  Map<String, Object?>? _creationParams;
  int? _lastNativeFingerprint;
  Size? _intrinsicSize;

  static int _encodeMaterialBrightness(Brightness b) =>
      b == Brightness.light ? 0 : 1;

  int _materialCodecFor(BuildContext context) {
    final Brightness b =
        widget.materialBrightness ?? Theme.of(context).brightness;
    return _encodeMaterialBrightness(b);
  }

  bool _effectiveLayoutRtl(BuildContext context) =>
      widget.layoutRtl ?? (Directionality.of(context) == TextDirection.rtl);

  static int? _tintKey(Color? c) => c?.toARGB32();

  @override
  void initState() {
    super.initState();
    if (isNativeUiSupported) {
      _creationParams = <String, Object?>{
        'value': widget.value,
        'enabled': widget.enabled,
        'materialBrightness': _kMaterialUnspecified,
        'layoutRtl': false,
      };
    }
  }

  @override
  void didUpdateWidget(IosSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _flushNativeParamsIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flushNativeParamsIfNeeded();
  }

  void _flushNativeParamsIfNeeded() {
    if (!isNativeUiSupported) {
      return;
    }
    final MethodChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    final int material = _materialCodecFor(context);
    final bool rtl = _effectiveLayoutRtl(context);
    final int fp = Object.hash(
      widget.value,
      widget.enabled,
      material,
      rtl,
      _tintKey(widget.onTintColor),
      _tintKey(widget.thumbTintColor),
      _tintKey(widget.offTrackTintColor),
    );
    if (_lastNativeFingerprint == fp) {
      return;
    }
    _lastNativeFingerprint = fp;
    ch.invokeMethod<void>('update', <String, Object?>{
      'value': widget.value,
      'enabled': widget.enabled,
      'materialBrightness': material,
      'layoutRtl': rtl,
      'onTintArgb': widget.onTintColor?.toARGB32() ?? _kNativeTintUnset,
      'thumbTintArgb': widget.thumbTintColor?.toARGB32() ?? _kNativeTintUnset,
      'offTrackTintArgb':
          widget.offTrackTintColor?.toARGB32() ?? _kNativeTintUnset,
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  Future<void> _onPlatformMessage(MethodCall call) async {
    if (call.method != 'valueChanged') {
      return;
    }
    final Object? raw = call.arguments;
    bool? next;
    if (raw is Map) {
      next = raw['value'] as bool?;
    }
    if (next != null && next != widget.value) {
      widget.onChanged(next);
    }
  }

  Future<void> _loadIntrinsicSize() async {
    final MethodChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    try {
      final Object? raw = await ch.invokeMethod<Object?>('getIntrinsicSize');
      if (raw is! Map) {
        return;
      }
      final double? width = (raw['width'] as num?)?.toDouble();
      final double? height = (raw['height'] as num?)?.toDouble();
      if (width == null || height == null || width <= 0 || height <= 0) {
        return;
      }
      final Size next = Size(width * 1.1, height);
      if (!mounted || _intrinsicSize == next) {
        return;
      }
      setState(() => _intrinsicSize = next);
    } on PlatformException {
      // Keep layout tight until native reports size.
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size? size = _intrinsicSize;
    final Widget platformView = UiKitView(
      viewType: _viewType,
      creationParams: _creationParams!,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) async {
        _channel = MethodChannel('$_channelPrefix$id')
          ..setMethodCallHandler((MethodCall call) async {
            await _onPlatformMessage(call);
          });
        _lastNativeFingerprint = null;
        _flushNativeParamsIfNeeded();
        await _loadIntrinsicSize();
      },
    );

    if (size == null) {
      return SizedBox(
        width: 0,
        height: 0,
        child: Offstage(child: platformView),
      );
    }

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: UnconstrainedBox(
        constrainedAxis: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        child: UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: platformView,
          ),
        ),
      ),
    );
  }
}
