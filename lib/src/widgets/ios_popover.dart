import 'package:flutter/material.dart';

final Map<String, IosPopoverLink> _popoverLinksById =
    <String, IosPopoverLink>{};

/// Binds an [IosButton] anchor for native `UIMenu` (Safari-style morph).
/// See: https://developer.apple.com/documentation/uikit/uimenu
class IosPopoverLink {
  IosPopoverLink({String? transitionId, this.cornerRadius = 22.5})
    : transitionId =
          transitionId ??
          'ios_popover_${DateTime.now().microsecondsSinceEpoch}' {
    _popoverLinksById[this.transitionId] = this;
  }

  final String transitionId;
  final GlobalKey anchorKey = GlobalKey();
  final double cornerRadius;

  /// Set by [IosButton] when its platform view is created.
  int? nativeButtonViewId;

  /// `true` while the native menu is on screen (hides the Flutter anchor).
  final ValueNotifier<bool> menuPresented = ValueNotifier<bool>(false);

  void dispose() {
    menuPresented.dispose();
    _popoverLinksById.remove(transitionId);
  }

  RenderBox? _anchorBox() {
    final BuildContext? ctx = anchorKey.currentContext;
    if (ctx == null) {
      return null;
    }
    final RenderObject? ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      return null;
    }
    return ro;
  }

  /// Window-global rect of the anchor (matches UIKit `convert(_:from: nil)`).
  IosPopoverAnchorGeometry? geometryOnScreen() {
    final RenderBox? button = _anchorBox();
    if (button == null) {
      return null;
    }
    final Offset topLeft = button.localToGlobal(Offset.zero);
    final Rect rect = topLeft & button.size;
    return IosPopoverAnchorGeometry(rect: rect, cornerRadius: cornerRadius);
  }
}

class IosPopoverAnchorGeometry {
  const IosPopoverAnchorGeometry({
    required this.rect,
    required this.cornerRadius,
  });

  final Rect rect;
  final double cornerRadius;
}

/// One action in a native `UIMenu`.
class IosPopoverAction {
  const IosPopoverAction({
    required this.title,
    this.systemImage,
    this.isDestructive = false,
  });

  final String title;
  final String? systemImage;
  final bool isDestructive;

  Map<String, Object?> encode() => <String, Object?>{
    'title': title,
    'systemImage': systemImage,
    'isDestructive': isDestructive,
  };
}
