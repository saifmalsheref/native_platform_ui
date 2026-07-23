import 'package:flutter/material.dart';
import 'package:native_platform_ui/native_platform_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _switchOn = true;
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey.shade200,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              NativeUi.glassContainer(
                cornerRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    NativeUi.button(
                      onPressed: () {},
                      title: '+',
                      options: const IosButtonOptions(cornerRadius: 16),
                    ),
                    const SizedBox(width: 12),
                    NativeUi.switchWidget(
                      value: _switchOn,
                      onChanged: (v) => setState(() => _switchOn = v),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              NativeUi.bottomNavigationBar(
                items: const [
                  IOSNavItem(icon: 'house.fill', title: 'Home'),
                  IOSNavItem(icon: 'gear', title: 'Settings'),
                ],
                selectedIndex: _selectedTab,
                onChanged: (i) => setState(() => _selectedTab = i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
