import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_platform_ui/native_platform_ui.dart';

/// Native [UiKitView] SF Symbols break inside modal routes (sheets, dialogs).
bool useNativeSfSymbolPlatformView(BuildContext? context) {
  if (!isNativeUiSupported) {
    return false;
  }
  if (context == null) {
    return true;
  }
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  if (route is PopupRoute<dynamic>) {
    return false;
  }
  return true;
}

Object _defaultCacheKey(SfSymbols symbol, Color? color) {
  return 'sf_sym|$symbol|${color?.toARGB32() ?? -1}';
}

class SfSymbolsWidget extends StatefulWidget {
  factory SfSymbolsWidget({
    Key? key,
    required SfSymbols symbol,
    Color? color,
    double size = 24,
  }) {
    return SfSymbolsWidget._(
      key: key ?? ValueKey<Object>(_defaultCacheKey(symbol, color)),
      symbol: symbol,
      color: color,
      size: size,
    );
  }

  const SfSymbolsWidget._({
    super.key,
    required this.symbol,
    this.color,
    this.size = 24,
  });

  final SfSymbols symbol;
  final Color? color;
  final double size;

  @override
  State<SfSymbolsWidget> createState() => _SfSymbolsWidgetState();
}

class _SfSymbolsWidgetState extends State<SfSymbolsWidget> {
  static const String _viewType = 'sf_symbols_view';
  static const String _channelPrefix = 'sf_symbols_';

  MethodChannel? _channel;

  Map<String, Object?> get _params => <String, Object?>{
    'symbol': widget.symbol.value,
    'color': widget.color?.toARGB32(),
  };

  void _sendToNative() {
    final ch = _channel;
    if (ch == null) {
      return;
    }
    ch.invokeMethod<void>('update', _params);
  }

  @override
  void didUpdateWidget(SfSymbolsWidget oldWidget) {
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
    if (!Platform.isIOS || !useNativeSfSymbolPlatformView(context)) {
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
          viewType: _viewType,
          creationParams: _params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (int id) {
            _channel = MethodChannel('$_channelPrefix$id');
            _sendToNative();
          },
        ),
      ),
    );
  }
}
