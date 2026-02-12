Future<String> startBackendLauncher({bool showTerminal = false}) async {
  throw UnsupportedError('Local backend launcher is not supported on this platform.');
}

Future<String> stopBackendLauncher() async {
  throw UnsupportedError('Local backend launcher is not supported on this platform.');
}

bool get backendLauncherSupported => false;
