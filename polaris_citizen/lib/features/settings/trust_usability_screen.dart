import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';

class TrustUsabilityScreen extends StatelessWidget {
  const TrustUsabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = CitizenPreferencesScope.of(context);
    final String languageCode = prefs.languageCode;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.verified_user_rounded, size: 28, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  CitizenStrings.tr('trust_title', languageCode),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Language selector — stacked layout to avoid overflow
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.language_rounded, size: 20, color: Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  Text(
                    CitizenStrings.tr('trust_language_label', languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const Key('trust-language-dropdown'),
                initialValue: prefs.languageCode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'en',
                    child: Text(CitizenStrings.tr('lang_english', languageCode)),
                  ),
                  DropdownMenuItem<String>(
                    value: 'hi',
                    child: Text(CitizenStrings.tr('lang_hindi', languageCode)),
                  ),
                  DropdownMenuItem<String>(
                    value: 'mr',
                    child: Text(CitizenStrings.tr('lang_marathi', languageCode)),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  prefs.setLanguageCode(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Data saver toggle
        InkWell(
          onTap: () => prefs.setDataSaverEnabled(!prefs.dataSaverEnabled),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: prefs.dataSaverEnabled
                  ? const Color(0xFF2F855A).withValues(alpha: 0.08)
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: prefs.dataSaverEnabled
                    ? const Color(0xFF2F855A).withValues(alpha: 0.2)
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  prefs.dataSaverEnabled
                      ? Icons.data_saver_on_rounded
                      : Icons.data_saver_off_rounded,
                  size: 24,
                  color: prefs.dataSaverEnabled
                      ? const Color(0xFF2F855A)
                      : const Color(0xFFB7791F),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    CitizenStrings.tr('trust_data_saver_title', languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  key: const Key('trust-data-saver-toggle'),
                  value: prefs.dataSaverEnabled,
                  onChanged: (bool value) => prefs.setDataSaverEnabled(value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
