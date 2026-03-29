import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/alerts/alert_severity_palette.dart';

void main() {
  test('maps citizen alert severities to the expected colors', () {
    expect(citizenAlertSeverityColor('EMERGENCY'), const Color(0xFFB71C1C));
    expect(citizenAlertSeverityColor('ALERT'), const Color(0xFFDD6B20));
    expect(citizenAlertSeverityColor('WARNING'), const Color(0xFFB7791F));
    expect(citizenAlertSeverityColor('WATCH'), const Color(0xFF2B6CB0));
    expect(citizenAlertSeverityColor('ADVISORY'), const Color(0xFF2F855A));
    expect(citizenAlertSeverityColor('INFO'), const Color(0xFF4A5568));
    expect(citizenAlertSeverityColor('unknown'), const Color(0xFF4A5568));
  });
}
