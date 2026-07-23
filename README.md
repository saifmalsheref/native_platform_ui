# native_platform_ui

Native iOS UI widgets for Flutter, backed by `UiKitView` / SwiftUI platform views.
On non-iOS platforms, widgets fall back to Material equivalents where applicable.

**Requires iOS 15+.** Liquid glass (`UIGlassEffect`) is used when available (iOS 26+).

## Install

```yaml
dependencies:
  native_platform_ui: ^0.0.1
```

```dart
import 'package:native_platform_ui/native_platform_ui.dart';
```

## Features

| API | Description |
| --- | --- |
| `NativeUi.button` / `IosButton` | Native `UIButton` with liquid-glass chrome, SF Symbols, linked button groups, popover menus |
| `NativeUi.switchWidget` / `IosSwitch` | Native `UISwitch` |
| `NativeUi.sfSymbol` / `SfSymbolsWidget` | Render SF Symbols natively |
| `NativeUi.glassContainer` / `PlatformContainer` | Glass / blur material container |
| `NativeUi.bottomNavigationBar` | Native-style bottom tab bar |
| `showIosAlert` | Native `UIAlertController` |
| `showIosPopover` | Native `UIMenu` anchored to a Flutter widget |
| `SfSymbols` | Typed SF Symbol names |

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:native_platform_ui/native_platform_ui.dart';

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  bool _on = true;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NativeUi.glassContainer(
              cornerRadius: 20,
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NativeUi.button(
                    title: '+',
                    onPressed: () {},
                    options: const IosButtonOptions(cornerRadius: 16),
                  ),
                  const SizedBox(width: 12),
                  NativeUi.switchWidget(
                    value: _on,
                    onChanged: (v) => setState(() => _on = v),
                  ),
                  const SizedBox(width: 12),
                  NativeUi.sfSymbol(SfSymbols.starSquareFill, size: 28),
                ],
              ),
            ),
            const Spacer(),
            NativeUi.bottomNavigationBar(
              items: const [
                IOSNavItem(icon: 'house.fill', title: 'Home'),
                IOSNavItem(icon: 'gear', title: 'Settings'),
              ],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Alert

```dart
await showIosAlert(
  context: context,
  title: 'Delete item?',
  message: 'This cannot be undone.',
  primaryButton: IosAlertButton(
    text: 'Delete',
    style: IosAlertButtonStyle.destructive,
    onTap: () {},
  ),
  cancelButton: const IosAlertButton(
    text: 'Cancel',
    style: IosAlertButtonStyle.cancel,
  ),
);
```

### Popover menu

```dart
await showIosPopover(
  context: context,
  actions: const [
    IosPopoverAction(title: 'Copy', systemImage: 'doc.on.doc'),
    IosPopoverAction(title: 'Delete', systemImage: 'trash', isDestructive: true),
  ],
  onSelect: (index) {},
);
```

### Capability check

```dart
final liquidGlass = await NativeUi.isIOS26AndAbove();
```

## Platform support

| Platform | Status |
| --- | --- |
| iOS | Native UIKit / SwiftUI views |
| Android / others | Material fallbacks for supported widgets; alerts/popovers no-op or Material dialogs where implemented |
| Web | Not supported (`isNativeUiSupported == false`) |

## License

MIT
