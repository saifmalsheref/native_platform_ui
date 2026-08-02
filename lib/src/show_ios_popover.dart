import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'platform.dart';
import 'widgets/ios_popover.dart';

const Set<String> _rtlLanguageCodes = <String>{
  'ar',
  'dv',
  'fa',
  'he',
  'ku',
  'ps',
  'sd',
  'ug',
  'ur',
  'yi',
};

bool _isRtlLocale(Locale locale) =>
    _rtlLanguageCodes.contains(locale.languageCode.toLowerCase());

bool _resolveLayoutRtl({
  bool? layoutRtl,
  Locale? locale,
  BuildContext? context,
}) {
  if (layoutRtl != null) return layoutRtl;
  if (locale != null) return _isRtlLocale(locale);
  if (context != null && context.mounted) {
    return Directionality.of(context) == TextDirection.rtl;
  }
  return false;
}

const MethodChannel _popoverChannel = MethodChannel('ios_native_popover');
const MethodChannel _popoverEventsChannel = MethodChannel(
  'ios_native_popover_events',
);

const Duration _kPopoverPresentDelay = Duration(milliseconds: 120);
const Duration _kPopoverSelectionDelay = Duration(milliseconds: 100);

/// Resolves a window-global anchor rect for [showIosPopover].
Rect? resolveIosPopoverAnchorRect({
  GlobalKey? anchorKey,
  BuildContext? anchorContext,
  Rect? anchorRect,
}) {
  if (anchorRect != null) {
    return anchorRect;
  }
  final BuildContext? ctx = anchorKey?.currentContext ?? anchorContext;
  if (ctx == null) {
    return null;
  }
  final RenderObject? renderObject = ctx.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  final Offset topLeft = renderObject.localToGlobal(Offset.zero);
  return topLeft & renderObject.size;
}

void _clearAnchorMenuHandler() {
  _popoverEventsChannel.setMethodCallHandler(null);
}

void _dispatchPopoverSelection(ValueChanged<int> onSelect, int index) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>.delayed(_kPopoverSelectionDelay, () {
        onSelect(index);
      }),
    );
  });
}

Future<void> _waitForTriggerGestureToEnd() async {
  final Completer<void> completer = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>.delayed(_kPopoverPresentDelay, completer.complete),
    );
  });
  await completer.future;
}

/// Presents a native iOS `UIMenu` anchored to a Flutter widget rect.
///
/// [context] is required for anchor positioning and locale / layout direction.
/// Override with [locale] or [layoutRtl] when context locale is unavailable.
/// [onSelect] receives the tapped action index.
///
/// Returns `true` when the native menu presentation was requested successfully.
Future<bool> showIosPopover({
  required BuildContext context,
  required List<IosPopoverAction> actions,
  required ValueChanged<int> onSelect,
  Rect? anchorRect,
  Locale? locale,
  bool? layoutRtl,
  double cornerRadius = 12,
}) async {
  if (actions.isEmpty || !context.mounted) {
    return false;
  }

  final Locale resolvedLocale = locale ?? Localizations.localeOf(context);
  final bool rtl = _resolveLayoutRtl(
    layoutRtl: layoutRtl,
    locale: resolvedLocale,
    context: context,
  );
  final String cancelTitle = CupertinoLocalizations.of(
    context,
  ).cancelButtonLabel;

  final Rect? rect = resolveIosPopoverAnchorRect(
    anchorRect: anchorRect,
    anchorContext: context,
  );
  if (rect == null) {
    return false;
  }

  if (!isNativeUiSupported) {
    return false;
  }

  _clearAnchorMenuHandler();
  _popoverEventsChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'anchorMenuSelected':
        _clearAnchorMenuHandler();
        final Object? raw = call.arguments;
        final int? index = raw is int ? raw : (raw is num ? raw.toInt() : null);
        if (index != null && index >= 0 && index < actions.length) {
          _dispatchPopoverSelection(onSelect, index);
        }
      case 'anchorMenuDismissed':
        _clearAnchorMenuHandler();
    }
  });

  await _waitForTriggerGestureToEnd();
  if (!context.mounted) {
    _clearAnchorMenuHandler();
    return false;
  }

  try {
    await _popoverChannel
        .invokeMethod<void>('presentMenuAtAnchor', <String, Object?>{
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
          'sourceCornerRadius': cornerRadius,
          'layoutRtl': rtl,
          'localeLanguageCode': resolvedLocale.languageCode,
          'cancelTitle': cancelTitle,
          'actions': actions.map((IosPopoverAction e) => e.encode()).toList(),
        });
    return true;
  } on PlatformException {
    _clearAnchorMenuHandler();
    return false;
  }
}
