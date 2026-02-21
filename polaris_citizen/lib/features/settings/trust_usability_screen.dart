import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';

class TrustUsabilityScreen extends StatelessWidget {
  const TrustUsabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = CitizenPreferencesScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'App Language',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose your preferred language for clearer instructions during emergencies.',
                ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Language',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'en', child: Text('English')),
                DropdownMenuItem<String>(value: 'hi', child: Text('Hindi')),
                DropdownMenuItem<String>(value: 'mr', child: Text('Marathi')),
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
