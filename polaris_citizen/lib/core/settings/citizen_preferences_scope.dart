import 'package:flutter/material.dart';
import 'citizen_preferences.dart';

class CitizenPreferencesScope
    extends InheritedNotifier<CitizenPreferencesController> {
  const CitizenPreferencesScope({
    super.key,
    required CitizenPreferencesController controller,
    required super.child,
  }) : super(notifier: controller);

  static CitizenPreferencesController of(BuildContext context) {
    final CitizenPreferencesScope? scope = context
        .dependOnInheritedWidgetOfExactType<CitizenPreferencesScope>();
    assert(scope != null, 'CitizenPreferencesScope not found in widget tree.');
    return scope!.notifier!;
  }

  static CitizenPreferencesController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CitizenPreferencesScope>()
        ?.notifier;
  }
}
