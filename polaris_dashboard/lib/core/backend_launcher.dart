import 'backend_launcher_stub.dart'
    if (dart.library.io) 'backend_launcher_io.dart' as impl;

Future<String> startBackendLauncher({bool showTerminal = false}) =>
    impl.startBackendLauncher(showTerminal: showTerminal);

Future<String> stopBackendLauncher() => impl.stopBackendLauncher();

bool get backendLauncherSupported => impl.backendLauncherSupported;
