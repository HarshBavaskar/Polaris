import 'dart:io';

Future<String> startBackendLauncher({bool showTerminal = false}) async {
  if (!backendLauncherSupported) {
    throw UnsupportedError('Backend launcher is available only on desktop.');
  }

  final scriptPath = _resolveLauncherScript();
  if (scriptPath == null) {
    throw StateError('Launcher script not found (start-polaris.ps1).');
  }

  await Process.start(
    'powershell.exe',
    [
      '-NoLogo',
      '-NonInteractive',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      if (showTerminal) '-ShowTerminal',
    ],
    runInShell: false,
    mode: ProcessStartMode.detached,
  );

  return showTerminal
      ? 'Backend launcher started with visible terminal.'
      : 'Backend launcher started.';
}

Future<String> stopBackendLauncher() async {
  if (!backendLauncherSupported) {
    throw UnsupportedError('Backend launcher is available only on desktop.');
  }

const stopScript = r"""
$ErrorActionPreference = "SilentlyContinue"
$repoRoot = "D:\Polaris"
$runtimeDir = Join-Path $repoRoot "app\runtime"
$pidFiles = @(
  Join-Path $runtimeDir "backend_pid.txt",
  Join-Path $runtimeDir "router_pid.txt"
)

foreach ($pidFile in $pidFiles) {
  if (Test-Path $pidFile) {
    $pidText = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($pidText) {
      $pid = [int]$pidText
      taskkill /PID $pid /T /F | Out-Null
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
  }
}

$targets = @(
  'uvicorn app.main:app',
  '-m uvicorn app.main:app',
  'app.notifications.valkey_router'
)

foreach ($target in $targets) {
  Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -like "*$target*" } |
    ForEach-Object {
      Stop-Process -Id $_.ProcessId -Force
    }
}
""";

  await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      stopScript,
    ],
    runInShell: false,
  );

  return 'Backend stop signal sent.';
}

bool get backendLauncherSupported => Platform.isWindows;

String? _resolveLauncherScript() {
  const fixed = r'D:\Polaris\app\notifications\start-polaris.ps1';
  if (File(fixed).existsSync()) return fixed;

  final cwd = Directory.current.path;
  final candidates = <String>[
    '$cwd\\app\\notifications\\start-polaris.ps1',
    '$cwd\\..\\app\\notifications\\start-polaris.ps1',
    '$cwd\\..\\..\\app\\notifications\\start-polaris.ps1',
  ];

  for (final c in candidates) {
    if (File(c).existsSync()) return File(c).absolute.path;
  }
  return null;
}
