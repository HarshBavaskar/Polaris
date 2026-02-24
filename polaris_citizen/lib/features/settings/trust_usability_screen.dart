import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';

class TrustUsabilityScreen extends StatelessWidget {
  const TrustUsabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = CitizenPreferencesScope.of(context);
    final String languageCode = prefs.languageCode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  CitizenStrings.tr('trust_title', languageCode),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(CitizenStrings.tr('trust_desc', languageCode)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              key: const Key('trust-language-dropdown'),
              initialValue: prefs.languageCode,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: CitizenStrings.tr(
                  'trust_language_label',
                  languageCode,
                ),
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
          ),
        ),
      ],
    );
  }
}
