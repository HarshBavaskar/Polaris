class RefreshConfig {
  // UI animations are frame-synced and tuned for high refresh displays (90/120Hz).
  static const Duration screenSwitchAnimation = Duration(milliseconds: 180);
  static const Duration marqueeMinCycle = Duration(seconds: 8);

  // Polling intervals tuned for smoother live updates without backend flooding.
  static const Duration appAlertPoll = Duration(seconds: 3);
  static const Duration topBarEventsPoll = Duration(seconds: 8);
  static const Duration overviewCameraPoll = Duration(seconds: 1);
  static const Duration overviewDecisionPoll = Duration(milliseconds: 900);
  static const Duration mapPoll = Duration(seconds: 2);
  static const Duration trendsPoll = Duration(seconds: 3);
  static const Duration alertsPoll = Duration(seconds: 6);

  // Marquee travel speed in pixels/second for smooth readable movement.
  static const double marqueePixelsPerSecond = 95;
}
