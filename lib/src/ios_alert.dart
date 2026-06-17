import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform.dart';

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

int? _encodeMaterialBrightness(Brightness? brightness) {
  if (brightness == null) return null;
  return brightness == Brightness.light ? 0 : 1;
}

/// Theme defaults for [showIosAlert], typically from [IosAlertTheme.of].
@immutable
class IosAlertTheme {
  const IosAlertTheme({
    this.titleColor,
    this.messageColor,
    this.brightness,
  });

  final Color? titleColor;
  final Color? messageColor;
  final Brightness? brightness;

  static const IosAlertTheme fallback = IosAlertTheme();

  /// Reads colors and brightness from the app [Theme] / [CupertinoTheme].
  factory IosAlertTheme.of(BuildContext context) {
    final ThemeData material = Theme.of(context);
    final CupertinoThemeData cupertino = CupertinoTheme.of(context);
    final ColorScheme colors = material.colorScheme;
    final Color onSurface =
        cupertino.textTheme.textStyle.color ?? colors.onSurface;

    return IosAlertTheme(
      titleColor: onSurface,
      messageColor: onSurface.withValues(alpha: 0.72),
      brightness: material.brightness,
    );
  }

  IosAlertTheme copyWith({
    Color? titleColor,
    Color? messageColor,
    Brightness? brightness,
    bool clearBrightness = false,
  }) {
    return IosAlertTheme(
      titleColor: titleColor ?? this.titleColor,
      messageColor: messageColor ?? this.messageColor,
      brightness: clearBrightness ? null : (brightness ?? this.brightness),
    );
  }
}

/// Optional alert styling overrides.
@immutable
class IosAlertOptions {
  const IosAlertOptions({
    this.titleColor,
    this.messageColor,
    this.brightness,
  });

  final Color? titleColor;
  final Color? messageColor;
  final Brightness? brightness;
}

/// Visual role of a button in [showIosAlert].
enum IosAlertButtonStyle {
  /// Standard action (`UIAlertAction.Style.default`).
  standard,

  /// Dismissive action (`UIAlertAction.Style.cancel`).
  cancel,

  /// Destructive action (`UIAlertAction.Style.destructive`).
  destructive,
}

/// One action in a native `UIAlertController`.
class IosAlertButton {
  const IosAlertButton({
    required this.text,
    this.color,
    this.onTap,
    this.style = IosAlertButtonStyle.standard,
    this.isPreferred = false,
    this.enabled = true,
  });

  final String text;
  final Color? color;
  final VoidCallback? onTap;
  final IosAlertButtonStyle style;
  final bool isPreferred;
  final bool enabled;

  Map<String, Object?> encode() => <String, Object?>{
    'text': text,
    'color': color?.toARGB32(),
    'style': style.index,
    'isPreferred': isPreferred,
    'enabled': enabled,
  };
}

const MethodChannel _alertChannel = MethodChannel('native_ui');

/// Presents a native iOS alert (`UIAlertController`).
///
/// Theme defaults are resolved synchronously from [context] via
/// [IosAlertTheme.of] before the alert is shown. Pass [theme] or [options]
/// to override.
Future<void> showIosAlert({
  required String title,
  String? message,
  Color? titleColor,
  Color? messageColor,
  required IosAlertButton primaryButton,
  IosAlertButton? cancelButton,
  BuildContext? context,
  IosAlertTheme? theme,
  IosAlertOptions? options,
  Locale? locale,
  bool? layoutRtl,
  bool barrierDismissible = true,
}) async {
  final IosAlertTheme resolvedTheme =
      theme ??
      (context != null && context.mounted
          ? IosAlertTheme.of(context)
          : IosAlertTheme.fallback);

  final Brightness? resolvedBrightness =
      options?.brightness ??
      resolvedTheme.brightness ??
      (context != null && context.mounted
          ? Theme.of(context).brightness
          : null);
  final Color? resolvedTitleColor =
      titleColor ?? options?.titleColor ?? resolvedTheme.titleColor;
  final Color? resolvedMessageColor =
      messageColor ?? options?.messageColor ?? resolvedTheme.messageColor;

  final bool rtl = _resolveLayoutRtl(
    layoutRtl: layoutRtl,
    locale: locale,
    context: context,
  );

  if (isNativeUiSupported) {
    final String? tapped = await _alertChannel
        .invokeMethod<String>('showIosAlert', <String, Object?>{
          'title': title,
          'message': message,
          'titleColor': resolvedTitleColor?.toARGB32(),
          'messageColor': resolvedMessageColor?.toARGB32(),
          'primaryButton': primaryButton.encode(),
          'cancelButton': cancelButton?.encode(),
          'layoutRtl': rtl,
          'localeLanguageCode': locale?.languageCode,
          'barrierDismissible': barrierDismissible,
          if (_encodeMaterialBrightness(resolvedBrightness) case final int b)
            'materialBrightness': b,
        });
    switch (tapped) {
      case 'primary':
        primaryButton.onTap?.call();
      case 'cancel':
        cancelButton?.onTap?.call();
      case 'dismiss':
        break;
    }
    return;
  }

  if (context == null || !context.mounted) {
    throw UnsupportedError(
      'showIosAlert requires a mounted BuildContext on non-iOS platforms.',
    );
  }

  await showCupertinoDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext ctx) {
      Widget dialog = CupertinoAlertDialog(
        title: Text(
          title,
          style: resolvedTitleColor != null
              ? TextStyle(color: resolvedTitleColor)
              : null,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        ),
        content: message == null
            ? null
            : Text(
                message,
                style: resolvedMessageColor != null
                    ? TextStyle(color: resolvedMessageColor)
                    : null,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              ),
        actions: <Widget>[
          if (cancelButton != null)
            CupertinoDialogAction(
              isDefaultAction: cancelButton.isPreferred,
              isDestructiveAction:
                  cancelButton.style == IosAlertButtonStyle.destructive,
              onPressed: cancelButton.enabled
                  ? () {
                      Navigator.of(ctx).pop();
                      cancelButton.onTap?.call();
                    }
                  : null,
              textStyle: cancelButton.color != null
                  ? TextStyle(color: cancelButton.color)
                  : null,
              child: Text(
                cancelButton.text,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
          CupertinoDialogAction(
            isDefaultAction: primaryButton.isPreferred,
            isDestructiveAction:
                primaryButton.style == IosAlertButtonStyle.destructive,
            onPressed: primaryButton.enabled
                ? () {
                    Navigator.of(ctx).pop();
                    primaryButton.onTap?.call();
                  }
                : null,
            textStyle: primaryButton.color != null
                ? TextStyle(color: primaryButton.color)
                : null,
            child: Text(
              primaryButton.text,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ],
      );

      if (locale != null) {
        dialog = Localizations.override(
          context: ctx,
          locale: locale,
          child: dialog,
        );
      }

      return Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: dialog,
      );
    },
  );
}
