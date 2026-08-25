import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:native_platform_ui/src/platform.dart';

int _bottomNavItemsPayloadFingerprint(List<Map<String, dynamic>> data) {
  int h = 0;
  for (final Map<String, dynamic> m in data) {
    final Object? icon = m['icon'];
    final int iconLen = icon is String ? icon.length : 0;
    final Object? activeIcon = m['activeIcon'];
    h = Object.hash(
      h,
      m['title'],
      m['iconType'],
      iconLen,
      activeIcon is String ? activeIcon.length : 0,
      m['activeTextColor'],
      m['inactiveTextColor'],
      m['activeImageColor'],
      m['inactiveImageColor'],
      m['assetImage'],
      m['iconSize'],
      m['activeIconSize'],
    );
  }
  return h;
}

int _iosNavItemsFingerprint(List<IOSNavItem> items) {
  return Object.hashAll(items.map((IOSNavItem e) => e.hashCode));
}

/// How [NativeIOSBottomNavigationBar] renders items on iPad regular width.
///
/// Compact width (iPhone / iPad Split View) always uses icons and labels.
enum IOSPadBottomNavDisplayMode {
  /// Icons only (default).
  iconsOnly,

  /// Icons and titles, same as iPhone.
  iconsAndLabels,

  /// Titles only.
  labelsOnly,
}

/// Model for iOS navigation bar items.
class IOSNavItem {
  const IOSNavItem({
    required this.icon,
    required this.title,
    this.assetImage,
    this.activeIcon,
    this.activeTextColor,
    this.inactiveTextColor,
    this.activeImageColor,
    this.inactiveImageColor,
    this.iconSize,
    this.activeIconSize,
  });

  final String icon;
  final String title;
  final String? assetImage;
  final String? activeIcon;
  final Color? activeTextColor;
  final Color? inactiveTextColor;
  final Color? activeImageColor;
  final Color? inactiveImageColor;
  final double? iconSize;
  final double? activeIconSize;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IOSNavItem &&
            icon == other.icon &&
            title == other.title &&
            assetImage == other.assetImage &&
            activeIcon == other.activeIcon &&
            activeTextColor == other.activeTextColor &&
            inactiveTextColor == other.inactiveTextColor &&
            activeImageColor == other.activeImageColor &&
            inactiveImageColor == other.inactiveImageColor &&
            iconSize == other.iconSize &&
            activeIconSize == other.activeIconSize;
  }

  @override
  int get hashCode => Object.hash(
        icon,
        title,
        assetImage,
        activeIcon,
        activeTextColor,
        inactiveTextColor,
        activeImageColor,
        inactiveImageColor,
        iconSize,
        activeIconSize,
      );
}

/// Native iOS bottom navigation bar ([UiKitView] + `UITabBar`).
class NativeIOSBottomNavigationBar extends StatefulWidget {
  const NativeIOSBottomNavigationBar({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onChanged,
    this.tintColor,
    this.unselectedTintColor,
    this.materialBrightness,
    this.height = 60,
    this.iconSize,
    this.activeIconSize,
    this.padDisplayMode = IOSPadBottomNavDisplayMode.iconsOnly,
    this.titleFontSize,
    this.padTitleFontSize,
  });

  final List<IOSNavItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final Color? tintColor;
  final Color? unselectedTintColor;

  /// When null, uses [Theme.of] brightness from the widget tree.
  final Brightness? materialBrightness;

  final double height;

  /// Default icon size in points when [IOSNavItem.iconSize] is null.
  final double? iconSize;

  /// Default active icon size in points when [IOSNavItem.activeIconSize] is null.
  final double? activeIconSize;

  /// iPad regular-width item layout. Default is [IOSPadBottomNavDisplayMode.iconsOnly].
  final IOSPadBottomNavDisplayMode padDisplayMode;

  /// Title font size for compact width (iPhone / iPad Split View). Default `11`.
  final double? titleFontSize;

  /// Title font size for iPad regular width. Default `13`.
  final double? padTitleFontSize;

  @override
  State<NativeIOSBottomNavigationBar> createState() =>
      _NativeIOSBottomNavigationBarState();
}

class _NativeIOSBottomNavigationBarState
    extends State<NativeIOSBottomNavigationBar> {
  static const String _viewType = 'native_ios_bottom_nav_bar';
  static const String _channelPrefix = 'native_ios_bottom_nav_bar_';

  static int _encodeMaterialBrightness(Brightness brightness) =>
      brightness == Brightness.light ? 0 : 1;

  MethodChannel? _channel;
  bool _isPlatformViewCreated = false;
  double _nativeBottomSafeArea = 0;

  List<Map<String, dynamic>>? _preparedItemsData;
  int _prepareGeneration = 0;
  int _syncGeneration = 0;

  int? _lastItemsNativeFingerprint;
  int? _lastSentSelectedIndex;
  int? _lastSentChromeFingerprint;

  int? _pendingUserSelectedIndex;
  int? _lastWidgetItemsFingerprint;

  static final Map<String, String> _svgRasterPngBase64Cache =
      <String, String>{};
  static const int _svgRasterCacheMaxEntries = 24;

  static Future<String?> _rasterizeSvgAssetToPngBase64(
    String assetPath, {
    required double size,
  }) async {
    final String cacheKey = '$assetPath@${size.toStringAsFixed(1)}';
    final String? cached = _svgRasterPngBase64Cache[cacheKey];
    if (cached != null) {
      return cached;
    }
    try {
      final String svgString = await rootBundle.loadString(assetPath);
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(svgString),
        null,
      );
      ui.Image? image;
      try {
        final int pixelSize = size.ceil().clamp(12, 96);
        image = await pictureInfo.picture.toImage(pixelSize, pixelSize);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          return null;
        }
        final String encoded = base64Encode(byteData.buffer.asUint8List());
        _svgRasterPngBase64Cache[cacheKey] = encoded;
        while (_svgRasterPngBase64Cache.length > _svgRasterCacheMaxEntries) {
          _svgRasterPngBase64Cache.remove(_svgRasterPngBase64Cache.keys.first);
        }
        return encoded;
      } finally {
        image?.dispose();
        pictureInfo.picture.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _lastWidgetItemsFingerprint = _iosNavItemsFingerprint(widget.items);
    _prepareItemsData();
  }

  int _materialCodecFor(BuildContext context) {
    final Brightness? b = widget.materialBrightness;
    if (b == null) {
      return _encodeMaterialBrightness(Theme.of(context).brightness);
    }
    return _encodeMaterialBrightness(b);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isPlatformViewCreated) {
      unawaited(_pushChromeIfNeeded());
    }
  }

  @override
  void didUpdateWidget(NativeIOSBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final int itemsFp = _iosNavItemsFingerprint(widget.items);
    if (itemsFp != _lastWidgetItemsFingerprint ||
        widget.iconSize != oldWidget.iconSize ||
        widget.activeIconSize != oldWidget.activeIconSize) {
      _lastWidgetItemsFingerprint = itemsFp;
      _prepareItemsData();
    } else if (_isPlatformViewCreated) {
      unawaited(_syncToNative());
    }

    if ((widget.materialBrightness != oldWidget.materialBrightness ||
            widget.padDisplayMode != oldWidget.padDisplayMode ||
            widget.titleFontSize != oldWidget.titleFontSize ||
            widget.padTitleFontSize != oldWidget.padTitleFontSize) &&
        _isPlatformViewCreated) {
      _lastSentChromeFingerprint = null;
      unawaited(_pushChromeIfNeeded());
    }

    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _handleExternalSelectedIndexChange(widget.selectedIndex);
    }
  }

  void _handleExternalSelectedIndexChange(int newIndex) {
    if (_pendingUserSelectedIndex != null &&
        newIndex != _pendingUserSelectedIndex) {
      return;
    }
    if (_pendingUserSelectedIndex != null &&
        newIndex == _pendingUserSelectedIndex) {
      _pendingUserSelectedIndex = null;
    }
    if (_isPlatformViewCreated) {
      unawaited(_pushSelectedIndex(newIndex));
    }
  }

  void _detachNativeViewBridge() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _isPlatformViewCreated = false;
    _nativeBottomSafeArea = 0;
    _lastItemsNativeFingerprint = null;
    _lastSentSelectedIndex = null;
    _lastSentChromeFingerprint = null;
  }

  double get _totalHeight => widget.height + _nativeBottomSafeArea;

  Future<void> _prepareItemsData() async {
    final int gen = ++_prepareGeneration;
    final List<Map<String, dynamic>> itemsData = await Future.wait(
      widget.items.map(_prepareItemData),
    );
    if (!mounted || gen != _prepareGeneration) {
      return;
    }
    final int payloadFp = _bottomNavItemsPayloadFingerprint(itemsData);
    final bool payloadChanged = _lastItemsNativeFingerprint != payloadFp;
    setState(() => _preparedItemsData = itemsData);
    if (_isPlatformViewCreated && payloadChanged) {
      _lastItemsNativeFingerprint = null;
      unawaited(_syncToNative());
    }
  }

  Future<void> _syncToNative() async {
    if (!_isPlatformViewCreated || _channel == null) {
      return;
    }
    final int gen = ++_syncGeneration;
    await _pushItemsIfNeeded();
    if (!mounted || gen != _syncGeneration || !_isPlatformViewCreated) {
      return;
    }
    await _pushChromeIfNeeded();
    if (!mounted || gen != _syncGeneration || !_isPlatformViewCreated) {
      return;
    }
    await _pushSelectedIndex(_effectiveSelectedIndex());
  }

  int _effectiveSelectedIndex() {
    final int max = widget.items.length - 1;
    if (max < 0) {
      return 0;
    }
    return widget.selectedIndex.clamp(0, max);
  }

  int _padDisplayModeCodec() => widget.padDisplayMode.index;

  int _chromeFingerprint(BuildContext context) {
    return Object.hash(
      widget.tintColor?.toARGB32(),
      widget.unselectedTintColor?.toARGB32(),
      _materialCodecFor(context),
      _padDisplayModeCodec(),
      widget.titleFontSize,
      widget.padTitleFontSize,
    );
  }

  Map<String, Object?> _chromePayload(BuildContext context) {
    return <String, Object?>{
      'tintColor': widget.tintColor?.toARGB32(),
      'unselectedTintColor': widget.unselectedTintColor?.toARGB32(),
      'materialBrightness': _materialCodecFor(context),
      'padDisplayMode': _padDisplayModeCodec(),
      'titleFontSize': widget.titleFontSize,
      'padTitleFontSize': widget.padTitleFontSize,
    };
  }

  void _setupMethodChannel() {
    _channel?.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onItemSelected':
          final int? index = _parseItemIndex(call.arguments);
          if (index == null) {
            return;
          }
          _pendingUserSelectedIndex = index;
          _lastSentSelectedIndex = index;
          if (mounted) {
            widget.onChanged?.call(index);
          }
        case 'onBottomSafeAreaChanged':
          _handleBottomSafeAreaChanged(call.arguments);
      }
    });
  }

  void _handleBottomSafeAreaChanged(Object? arguments) {
    final double? inset = _parseBottomSafeArea(arguments);
    if (inset == null || !mounted || inset == _nativeBottomSafeArea) {
      return;
    }
    setState(() => _nativeBottomSafeArea = inset);
  }

  double? _parseBottomSafeArea(Object? arguments) {
    if (arguments is double) {
      return arguments;
    }
    if (arguments is num) {
      return arguments.toDouble();
    }
    return null;
  }

  int? _parseItemIndex(Object? arguments) {
    if (arguments is int) {
      return arguments;
    }
    if (arguments is num) {
      return arguments.toInt();
    }
    return null;
  }

  Future<void> _fetchBottomSafeAreaFromNative() async {
    if (_channel == null || !_isPlatformViewCreated) {
      return;
    }
    final MethodChannel ch = _channel!;
    try {
      final Object? result = await ch.invokeMethod<Object?>('getBottomSafeArea');
      if (!mounted || _channel != ch || !_isPlatformViewCreated) {
        return;
      }
      _handleBottomSafeAreaChanged(result);
    } on PlatformException catch (e) {
      if (_isDeallocatedError(e)) {
        _detachNativeViewBridge();
      }
    } catch (_) {}
  }

  Future<void> _pushSelectedIndex(int index) async {
    if (_channel == null || !_isPlatformViewCreated) {
      return;
    }
    if (_lastSentSelectedIndex == index) {
      return;
    }
    final MethodChannel ch = _channel!;
    try {
      await ch.invokeMethod<void>('setSelectedIndex', <String, Object?>{
        'index': index,
      });
      if (!mounted || _channel != ch || !_isPlatformViewCreated) {
        return;
      }
      _lastSentSelectedIndex = index;
    } on PlatformException catch (e) {
      if (_isDeallocatedError(e)) {
        _detachNativeViewBridge();
      }
    } catch (_) {}
  }

  Future<void> _pushItemsIfNeeded() async {
    final List<Map<String, dynamic>>? data = _preparedItemsData;
    if (_channel == null || !_isPlatformViewCreated || data == null) {
      return;
    }
    final int fp = _bottomNavItemsPayloadFingerprint(data);
    if (fp == _lastItemsNativeFingerprint) {
      return;
    }
    final MethodChannel ch = _channel!;
    try {
      await ch.invokeMethod<void>('updateItems', <String, Object?>{
        'items': data,
      });
      if (!mounted || _channel != ch || !_isPlatformViewCreated) {
        return;
      }
      _lastItemsNativeFingerprint = fp;
    } on PlatformException catch (e) {
      if (_isDeallocatedError(e)) {
        _detachNativeViewBridge();
      }
    } catch (_) {}
  }

  Future<void> _pushChromeIfNeeded() async {
    if (_channel == null || !_isPlatformViewCreated || !mounted) {
      return;
    }
    final int fp = _chromeFingerprint(context);
    if (fp == _lastSentChromeFingerprint) {
      return;
    }
    final MethodChannel ch = _channel!;
    try {
      await ch.invokeMethod<void>('updateChrome', _chromePayload(context));
      if (!mounted || _channel != ch || !_isPlatformViewCreated) {
        return;
      }
      _lastSentChromeFingerprint = fp;
    } on PlatformException catch (e) {
      if (_isDeallocatedError(e)) {
        _detachNativeViewBridge();
      }
    } catch (_) {}
  }

  bool _isDeallocatedError(PlatformException e) {
    return e.code == 'DEALLOCATED' ||
        (e.message?.contains('deallocated') ?? false);
  }

  double _resolveIconSize(IOSNavItem item) =>
      item.iconSize ?? widget.iconSize ?? 22;

  double _resolveActiveIconSize(IOSNavItem item) =>
      item.activeIconSize ?? item.iconSize ?? widget.activeIconSize ?? _resolveIconSize(item);

  Future<Map<String, dynamic>> _prepareItemData(IOSNavItem item) async {
    final double iconSize = _resolveIconSize(item);
    final double activeIconSize = _resolveActiveIconSize(item);

    String? iconData;
    String? iconType;

    final String iconLower = item.icon.toLowerCase();
    if (iconLower.endsWith('.svg')) {
      final String? raster = await _rasterizeSvgAssetToPngBase64(
        item.icon,
        size: iconSize,
      );
      if (raster != null) {
        iconData = raster;
        iconType = 'svg';
      } else {
        iconData = item.icon;
        iconType = 'sfSymbol';
      }
    } else if (item.assetImage != null) {
      iconData = item.assetImage;
      iconType = 'asset';
    } else {
      iconData = item.icon;
      iconType = 'sfSymbol';
    }

    String? activeIconData;
    String? activeIconType;
    if (item.activeIcon != null) {
      final String activeIconLower = item.activeIcon!.toLowerCase();
      if (activeIconLower.endsWith('.svg')) {
        final String? raster = await _rasterizeSvgAssetToPngBase64(
          item.activeIcon!,
          size: activeIconSize,
        );
        if (raster != null) {
          activeIconData = raster;
          activeIconType = 'svg';
        } else {
          activeIconData = item.activeIcon;
          activeIconType = 'sfSymbol';
        }
      } else {
        activeIconData = item.activeIcon;
        activeIconType = 'sfSymbol';
      }
    }

    return <String, dynamic>{
      'icon': iconData ?? item.icon,
      'iconType': iconType,
      'activeIcon': activeIconData,
      'activeIconType': activeIconType,
      'title': item.title,
      'assetImage': item.assetImage,
      'activeTextColor': item.activeTextColor?.toARGB32(),
      'inactiveTextColor': item.inactiveTextColor?.toARGB32(),
      'activeImageColor': item.activeImageColor?.toARGB32(),
      'inactiveImageColor': item.inactiveImageColor?.toARGB32(),
      'iconSize': iconSize,
      'activeIconSize': activeIconSize,
    };
  }

  @override
  void dispose() {
    _detachNativeViewBridge();
    _pendingUserSelectedIndex = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNativeUiSupported) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>>? prepared = _preparedItemsData;
    if (prepared == null) {
      return SizedBox(height: _totalHeight);
    }

    return SizedBox(
      height: _totalHeight,
      child: UiKitView(
        viewType: _viewType,
        creationParams: <String, Object?>{
          'items': prepared,
          'selectedIndex': _effectiveSelectedIndex(),
          'tintColor': widget.tintColor?.toARGB32(),
          'unselectedTintColor': widget.unselectedTintColor?.toARGB32(),
          'materialBrightness': _materialCodecFor(context),
          'padDisplayMode': _padDisplayModeCodec(),
          'titleFontSize': widget.titleFontSize,
          'padTitleFontSize': widget.padTitleFontSize,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) async {
          _isPlatformViewCreated = true;
          _lastItemsNativeFingerprint = null;
          _lastSentSelectedIndex = null;
          _lastSentChromeFingerprint = null;
          _channel = MethodChannel('$_channelPrefix$id');
          _setupMethodChannel();
          await _fetchBottomSafeAreaFromNative();
          await _syncToNative();
        },
      ),
    );
  }
}
