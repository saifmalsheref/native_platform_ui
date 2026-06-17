import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_ui/native_ui.dart';

import 'platform_views.dart';

bool useNativeSfSymbolPlatformView(BuildContext? context) {
  if (!isNativeUiSupported) return false;
  if (context == null) return true;
  final route = ModalRoute.of(context);
  if (route is PopupRoute<dynamic>) return false;
  return true;
}

class SfSymbolWidget extends StatefulWidget {
  const SfSymbolWidget({
    super.key,
    required this.symbol,
    this.color,
    this.size = 24,
  });

  final SfSymbols symbol;
  final Color? color;
  final double size;

  @override
  State<SfSymbolWidget> createState() => _SfSymbolWidgetState();
}

class _SfSymbolWidgetState extends State<SfSymbolWidget> {
  MethodChannel? _channel;

  Map<String, Object?> get _params => <String, Object?>{
        'symbol': widget.symbol.value,
        'color': widget.color?.toARGB32(),
      };

  void _sendToNative() {
    _channel?.invokeMethod<void>('update', _params);
  }

  @override
  void didUpdateWidget(SfSymbolWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol || oldWidget.color != widget.color) {
      _sendToNative();
    }
  }

  @override
  void dispose() {
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.size;
    if (!useNativeSfSymbolPlatformView(context)) {
      return SizedBox(
        width: side,
        height: side,
        child: Icon(Icons.image_outlined, size: side, color: widget.color),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: side,
        height: side,
        child: UiKitView(
          viewType: NativeUiPlatformViews.sfSymbols,
          creationParams: _params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (int id) {
            _channel = MethodChannel('${NativeUiPlatformViews.sfSymbolsChannel}$id');
            _sendToNative();
          },
        ),
      ),
    );
  }
}
