import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// `true` when native iOS platform views from this package can be used.
bool get isNativeUiSupported => !kIsWeb && Platform.isIOS;
