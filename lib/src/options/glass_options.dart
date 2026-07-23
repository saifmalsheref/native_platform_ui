import 'package:flutter/material.dart';

/// SwiftUI `Glass` prominence — maps to `.regular`, `.clear`, `.prominent`.
enum IosGlassProminence {
  regular(0),
  clear(1),
  prominent(2);

  const IosGlassProminence(this.nativeCodec);

  /// Must match `IosGlassEffectSupport.swift`.
  final int nativeCodec;
}

/// Shape passed to `.glassEffect(_:in:)` — `.rect`, `.circle`, `.capsule`, etc.
enum IosGlassShapeKind {
  rect(0),
  circle(1),
  capsule(2),
  containerRelative(3),
  roundedRect(4);

  const IosGlassShapeKind(this.nativeCodec);

  /// Must match `IosGlassEffectSupport.swift`.
  final int nativeCodec;
}

/// Native glass clip shape. Use [IosGlassShape.rect] / [roundedRect] for corners.
@immutable
class IosGlassShape {
  const IosGlassShape._(this.kind, [this.cornerRadius]);

  const IosGlassShape.rect({double cornerRadius = 16})
    : this._(IosGlassShapeKind.rect, cornerRadius);

  const IosGlassShape.roundedRect({double cornerRadius = 16})
    : this._(IosGlassShapeKind.roundedRect, cornerRadius);

  const IosGlassShape.circle() : this._(IosGlassShapeKind.circle);

  const IosGlassShape.capsule() : this._(IosGlassShapeKind.capsule);

  const IosGlassShape.containerRelative()
    : this._(IosGlassShapeKind.containerRelative);

  final IosGlassShapeKind kind;
  final double? cornerRadius;

  bool get isCircle => kind == IosGlassShapeKind.circle;

  bool get isCapsule => kind == IosGlassShapeKind.capsule;

  double resolvedCornerRadius({
    required double fallback,
    double? width,
    double? height,
  }) {
    switch (kind) {
      case IosGlassShapeKind.circle:
      case IosGlassShapeKind.capsule:
        if (width != null && height != null) {
          return (width < height ? width : height) / 2;
        }
        return fallback;
      case IosGlassShapeKind.rect:
      case IosGlassShapeKind.roundedRect:
        return cornerRadius ?? fallback;
      case IosGlassShapeKind.containerRelative:
        return fallback;
    }
  }

  Map<String, Object?> toNativeMap({required double fallbackCornerRadius}) =>
      <String, Object?>{
        'glassShapeKind': kind.nativeCodec,
        'glassCornerRadius': cornerRadius ?? fallbackCornerRadius,
      };
}

/// Shared namespace for `.glassEffectUnion(id:namespace:)` across platform views.
///
/// **Important:** reuse the same instance for every surface in a union group.
/// Creating a new [IosGlassNamespace] per widget prevents linking.
@immutable
class IosGlassNamespace {
  IosGlassNamespace() : id = 'glass_ns_${_nextId++}';

  static int _nextId = 0;

  final String id;
}

/// Links adjacent glass platform views so outer corners round and inner edges
/// stay square (segmented control look).
///
/// Limitations with Flutter [UiKitView]:
/// - Each widget is a separate native embed; glass cannot refract across views
///   like SwiftUI `glassEffectUnion` / `UIGlassContainerEffect`.
/// - Siblings must touch with **zero** Flutter spacing between them.
/// - For multiple buttons in one pill, prefer [IosButton.linkedButtons] (single
///   native view) instead of several [IosButton]s with [IosGlassUnion].
@immutable
class IosGlassUnion {
  const IosGlassUnion({required this.id, required this.namespace});

  final String id;
  final IosGlassNamespace namespace;

  Map<String, Object?> toNativeMap() => <String, Object?>{
    'glassUnionId': id,
    'glassUnionNamespace': namespace.id,
  };
}

/// Options for `GlassEffectContainer` — spacing between grouped glass children.
@immutable
class IosGlassContainerOptions {
  const IosGlassContainerOptions({this.spacing = 0});

  final double spacing;

  Map<String, Object?> toNativeMap() => <String, Object?>{
    'glassContainerSpacing': spacing,
  };
}

/// How this surface sits in the blur stack. [nested] uses lighter materials.
enum IosGlassHierarchy {
  primary(0),
  nested(1);

  const IosGlassHierarchy(this.nativeCodec);

  /// Must match `LiquidGlassMaterialPlatformView.swift`.
  final int nativeCodec;
}

/// Native liquid-glass touch feedback (`UIGlassEffect.isInteractive` + press FX).
@immutable
class IosGlassInteraction {
  const IosGlassInteraction({
    this.native = true,
    this.pressScale = true,
    this.pressGlow = true,
  });

  final bool native;
  final bool pressScale;
  final bool pressGlow;

  bool get enabled => native || pressScale || pressGlow;

  static const IosGlassInteraction all = IosGlassInteraction();

  static const IosGlassInteraction nativeOnly = IosGlassInteraction(
    pressScale: false,
    pressGlow: false,
  );

  static const IosGlassInteraction none = IosGlassInteraction(
    native: false,
    pressScale: false,
    pressGlow: false,
  );

  IosGlassInteraction interactive([bool value = true]) =>
      value ? const IosGlassInteraction() : none;

  Map<String, Object?> toNativeMap() => <String, Object?>{
    'nativeInteractive': native,
    'pressScale': pressScale,
    'pressGlow': pressGlow,
    'interactive': enabled,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IosGlassInteraction &&
          native == other.native &&
          pressScale == other.pressScale &&
          pressGlow == other.pressGlow;

  @override
  int get hashCode => Object.hash(native, pressScale, pressGlow);
}

/// Unified glass configuration for every iOS platform view.
///
/// Mirrors SwiftUI:
/// `.glassEffect(.regular.tint(.blue).interactive(), in: .capsule)`
/// `GlassEffectContainer(spacing: 12) { … }`
/// `.glassEffectUnion(id: "toolbar", namespace: namespace)`
@immutable
class IosGlassOptions {
  const IosGlassOptions({
    this.prominence = IosGlassProminence.regular,
    this.shape = const IosGlassShape.rect(),
    this.tint,
    this.interaction,
    this.hierarchy = IosGlassHierarchy.primary,
    this.blurMaterial = 5,
    this.materialBrightness,
    this.union,
    this.container,
  });

  final IosGlassProminence prominence;
  final IosGlassShape shape;
  final Color? tint;
  final IosGlassInteraction? interaction;
  final IosGlassHierarchy hierarchy;

  /// Legacy `IosNativeBlurMaterial.nativeCodec`; default liquid glass (5).
  final int blurMaterial;
  final Brightness? materialBrightness;
  final IosGlassUnion? union;
  final IosGlassContainerOptions? container;

  static const IosGlassOptions regular = IosGlassOptions();

  static const IosGlassOptions clear = IosGlassOptions(
    prominence: IosGlassProminence.clear,
  );

  static const IosGlassOptions prominent = IosGlassOptions(
    prominence: IosGlassProminence.prominent,
  );

  IosGlassOptions copyWith({
    IosGlassProminence? prominence,
    IosGlassShape? shape,
    Color? tint,
    bool clearTint = false,
    IosGlassInteraction? interaction,
    bool clearInteraction = false,
    IosGlassHierarchy? hierarchy,
    int? blurMaterial,
    Brightness? materialBrightness,
    bool clearMaterialBrightness = false,
    IosGlassUnion? union,
    bool clearUnion = false,
    IosGlassContainerOptions? container,
    bool clearContainer = false,
  }) {
    return IosGlassOptions(
      prominence: prominence ?? this.prominence,
      shape: shape ?? this.shape,
      tint: clearTint ? null : (tint ?? this.tint),
      interaction: clearInteraction ? null : (interaction ?? this.interaction),
      hierarchy: hierarchy ?? this.hierarchy,
      blurMaterial: blurMaterial ?? this.blurMaterial,
      materialBrightness: clearMaterialBrightness
          ? null
          : (materialBrightness ?? this.materialBrightness),
      union: clearUnion ? null : (union ?? this.union),
      container: clearContainer ? null : (container ?? this.container),
    );
  }

  IosGlassOptions tinted(Color color, {double? opacity}) {
    final Color resolved = opacity != null
        ? color.withValues(alpha: opacity)
        : color;
    return copyWith(tint: resolved);
  }

  IosGlassOptions interactive([bool enabled = true]) => copyWith(
    interaction: enabled ? IosGlassInteraction.all : IosGlassInteraction.none,
  );

  IosGlassOptions inShape(IosGlassShape next) => copyWith(shape: next);

  IosGlassOptions withUnion(IosGlassUnion next) => copyWith(union: next);

  IosGlassOptions inContainer({double spacing = 0}) =>
      copyWith(container: IosGlassContainerOptions(spacing: spacing));

  IosGlassInteraction resolveInteraction({bool interactiveFallback = false}) {
    return interaction ??
        (interactiveFallback
            ? IosGlassInteraction.all
            : IosGlassInteraction.none);
  }

  double resolvedCornerRadius({
    double fallback = 16,
    double? width,
    double? height,
  }) {
    return shape.resolvedCornerRadius(
      fallback: fallback,
      width: width,
      height: height,
    );
  }

  /// Flat map for `StandardMessageCodec` — shared by all iOS platform views.
  Map<String, Object?> toNativeMap({
    required double cornerRadius,
    bool interactiveFallback = false,
    Brightness? themeBrightness,
  }) {
    final IosGlassInteraction resolved = resolveInteraction(
      interactiveFallback: interactiveFallback,
    );
    final Brightness? brightness = materialBrightness ?? themeBrightness;
    final int? materialCodec = brightness == null
        ? null
        : (brightness == Brightness.light ? 0 : 1);

    return <String, Object?>{
      'cornerRadius': cornerRadius,
      'isCircle': shape.isCircle,
      ...shape.toNativeMap(fallbackCornerRadius: cornerRadius),
      'glassProminence': prominence.nativeCodec,
      ...resolved.toNativeMap(),
      'tintColor': tint?.toARGB32(),
      'blurMaterial': blurMaterial,
      'glassHierarchy': hierarchy.nativeCodec,
      'materialBrightness': ?materialCodec,
      if (union != null) ...union!.toNativeMap(),
      if (container != null) ...container!.toNativeMap(),
    };
  }

  int fingerprint({
    required double cornerRadius,
    bool interactiveFallback = false,
    int? materialBrightnessCodec,
  }) {
    final IosGlassInteraction resolved = resolveInteraction(
      interactiveFallback: interactiveFallback,
    );
    return Object.hash(
      cornerRadius,
      shape.kind,
      shape.cornerRadius,
      prominence,
      resolved.native,
      resolved.pressScale,
      resolved.pressGlow,
      tint?.toARGB32(),
      blurMaterial,
      hierarchy,
      materialBrightnessCodec,
      union?.id,
      union?.namespace.id,
      container?.spacing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IosGlassOptions &&
          prominence == other.prominence &&
          shape.kind == other.shape.kind &&
          shape.cornerRadius == other.shape.cornerRadius &&
          tint == other.tint &&
          interaction == other.interaction &&
          hierarchy == other.hierarchy &&
          blurMaterial == other.blurMaterial &&
          materialBrightness == other.materialBrightness &&
          union?.id == other.union?.id &&
          union?.namespace.id == other.union?.namespace.id &&
          container?.spacing == other.container?.spacing;

  @override
  int get hashCode => Object.hash(
    prominence,
    shape.kind,
    shape.cornerRadius,
    tint,
    interaction,
    hierarchy,
    blurMaterial,
    materialBrightness,
    union?.id,
    union?.namespace.id,
    container?.spacing,
  );
}

/// Merges explicit [glass] with legacy per-widget fields (backward compatible).
IosGlassOptions resolveIosGlassOptions({
  IosGlassOptions? glass,
  double cornerRadius = 16,
  bool isCircle = false,
  bool interactive = false,
  IosGlassInteraction? glassInteraction,
  Color? tintColor,
  Brightness? materialBrightness,
  int blurMaterial = 5,
  IosGlassHierarchy glassHierarchy = IosGlassHierarchy.primary,
  IosGlassUnion? union,
  IosGlassContainerOptions? container,
}) {
  final IosGlassShape legacyShape = isCircle
      ? const IosGlassShape.circle()
      : IosGlassShape.rect(cornerRadius: cornerRadius);

  IosGlassShape mergeShape(IosGlassShape base) {
    if (isCircle) {
      return const IosGlassShape.circle();
    }
    switch (base.kind) {
      case IosGlassShapeKind.rect:
        return IosGlassShape.rect(cornerRadius: cornerRadius);
      case IosGlassShapeKind.roundedRect:
        return IosGlassShape.roundedRect(cornerRadius: cornerRadius);
      default:
        return base;
    }
  }

  final IosGlassOptions legacy = IosGlassOptions(
    shape: legacyShape,
    tint: tintColor,
    interaction:
        glassInteraction ??
        (interactive ? IosGlassInteraction.all : IosGlassInteraction.none),
    hierarchy: glassHierarchy,
    blurMaterial: blurMaterial,
    materialBrightness: materialBrightness,
    union: union,
    container: container,
  );

  if (glass == null) {
    return legacy;
  }

  return glass.copyWith(
    shape: mergeShape(glass.shape),
    tint: tintColor ?? glass.tint,
    interaction: glassInteraction ?? glass.interaction,
    materialBrightness: materialBrightness ?? glass.materialBrightness,
    blurMaterial: blurMaterial != 5 ? blurMaterial : glass.blurMaterial,
    hierarchy: glassHierarchy != IosGlassHierarchy.primary
        ? glassHierarchy
        : glass.hierarchy,
    union: union ?? glass.union,
    container: container ?? glass.container,
  );
}
