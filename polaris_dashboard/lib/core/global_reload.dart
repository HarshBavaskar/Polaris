import 'dart:async';
import 'package:flutter/foundation.dart';

class GlobalReload extends ChangeNotifier {
  Timer? _timer;

  void start({Duration interval = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      notifyListeners();
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
