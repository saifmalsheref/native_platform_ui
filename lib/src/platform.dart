import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

bool get isNativeUiSupported => !kIsWeb && Platform.isIOS;
