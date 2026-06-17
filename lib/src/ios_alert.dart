import 'package:flutter/cupertino.dart';
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
/// On iOS 26+, the system applies Liquid Glass to alerts automatically.
/// On other platforms, falls back to [CupertinoAlertDialog] when [context]
/// is provided.
///
/// Text direction resolves in order: [layoutRtl], [locale] (`ar` → RTL,
/// `en` → LTR), then [Directionality] from [context].
///
/// Set [barrierDismissible] to `true` to dismiss when tapping outside the
/// alert. Defaults to `false` (standard iOS alert behavior).
Future<void> showIosAlert({
  required String title,
  String? message,
  Color? titleColor,
  Color? messageColor,
  required IosAlertButton primaryButton,
  IosAlertButton? cancelButton,
  Locale? locale,
  bool? layoutRtl,
  bool barrierDismissible = false,
  BuildContext? context,
}) async {
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
          'titleColor': titleColor?.toARGB32(),
          'messageColor': messageColor?.toARGB32(),
          'primaryButton': primaryButton.encode(),
          'cancelButton': cancelButton?.encode(),
          'layoutRtl': rtl,
          'localeLanguageCode': locale?.languageCode,
          'barrierDismissible': barrierDismissible,
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
          style: titleColor != null ? TextStyle(color: titleColor) : null,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        ),
        content: message == null
            ? null
            : Text(
                message,
                style: messageColor != null
                    ? TextStyle(color: messageColor)
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
