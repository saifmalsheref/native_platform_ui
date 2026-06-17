import 'package:flutter/material.dart';
import 'package:native_ui/src/platform.dart';

/// Tracks Flutter modal overlays (reserved for future native compositing hooks).
///
/// Native layer stabilization was removed: it washed out SF Symbol icons inside
/// bottom sheets and caused tab-bar ghosting.
final class IosPlatformViewOverlayController {
  IosPlatformViewOverlayController._();

  static final IosPlatformViewOverlayController instance =
      IosPlatformViewOverlayController._();

  static final IosOverlayRouteNavigatorObserver navigatorObserver =
      IosOverlayRouteNavigatorObserver();

  final Set<String> _activeSources = <String>{};

  void acquire(String source) {
    if (!isNativeUiSupported) {
      return;
    }
    _activeSources.add(source);
  }

  void release(String source) {
    if (!isNativeUiSupported) {
      return;
    }
    _activeSources.remove(source);
  }

  void releaseAfter(String source, Duration delay) {
    if (!isNativeUiSupported) {
      return;
    }
    Future<void>.delayed(delay, () {
      release(source);
    });
  }
}

/// Notifies [IosPlatformViewOverlayController] when popups (sheets, dialogs) open.
final class IosOverlayRouteNavigatorObserver extends NavigatorObserver {
  static bool _isPopupOverlay(Route<dynamic> route) {
    if (route is! PopupRoute<dynamic>) {
      return false;
    }
    final Color? barrier = route.barrierColor;
    if (barrier == null) {
      return true;
    }
    return barrier.a > 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopupOverlay(route)) {
      IosPlatformViewOverlayController.instance.acquire(
        'popup:${route.hashCode}',
      );
    }
    super.didPush(route, previousRoute);
  }

  Duration _releaseDelay(Route<dynamic> route) {
    if (route is TransitionRoute<dynamic>) {
      return route.transitionDuration + const Duration(milliseconds: 50);
    }
    return const Duration(milliseconds: 350);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopupOverlay(route)) {
      IosPlatformViewOverlayController.instance.releaseAfter(
        'popup:${route.hashCode}',
        _releaseDelay(route),
      );
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopupOverlay(route)) {
      IosPlatformViewOverlayController.instance.release(
        'popup:${route.hashCode}',
      );
    }
    super.didRemove(route, previousRoute);
  }
}
