class CitizenStrings {
  static const Map<String, Map<String, String>> _values =
      <String, Map<String, String>>{
        'en': <String, String>{
          'title_dashboard': 'Citizen Dashboard',
          'title_alerts': 'Alerts',
          'title_report': 'Report Flooding',
          'title_safe_zones': 'Safe Zones',
          'title_request_help': 'Request Help',
          'title_my_reports': 'My Reports',
          'title_trust': 'App Language',
          'menu': 'Citizen Menu',
          'navigation': 'Navigation',
          'dashboard': 'Dashboard',
          'alerts': 'Alerts',
          'report': 'Report Flooding',
          'safe_zones': 'Safe Zones',
          'request_help': 'Request Help',
          'my_reports': 'My Reports',
          'trust': 'App Language',
        },
        'hi': <String, String>{
          'title_dashboard': 'नागरिक डैशबोर्ड',
          'title_alerts': 'अलर्ट',
          'title_report': 'बाढ़ रिपोर्ट',
          'title_safe_zones': 'सुरक्षित क्षेत्र',
          'title_request_help': 'मदद अनुरोध',
          'title_my_reports': 'मेरी रिपोर्ट',
          'title_trust': 'ऐप भाषा',
          'menu': 'नागरिक मेनू',
          'navigation': 'नेविगेशन',
          'dashboard': 'डैशबोर्ड',
          'alerts': 'अलर्ट',
          'report': 'बाढ़ रिपोर्ट',
          'safe_zones': 'सुरक्षित क्षेत्र',
          'request_help': 'मदद अनुरोध',
          'my_reports': 'मेरी रिपोर्ट',
          'trust': 'ऐप भाषा',
        },
        'mr': <String, String>{
          'title_dashboard': 'नागरिक डॅशबोर्ड',
          'title_alerts': 'अलर्ट',
          'title_report': 'पूर नोंद',
          'title_safe_zones': 'सुरक्षित क्षेत्रे',
          'title_request_help': 'मदत विनंती',
          'title_my_reports': 'माझे अहवाल',
          'title_trust': 'अ‍ॅप भाषा',
          'menu': 'नागरिक मेनू',
          'navigation': 'नेव्हिगेशन',
          'dashboard': 'डॅशबोर्ड',
          'alerts': 'अलर्ट',
          'report': 'पूर नोंद',
          'safe_zones': 'सुरक्षित क्षेत्रे',
          'request_help': 'मदत विनंती',
          'my_reports': 'माझे अहवाल',
          'trust': 'अ‍ॅप भाषा',
        },
      };

  static String tr(String key, String languageCode) {
    final Map<String, String> dictionary =
        _values[languageCode] ?? _values['en']!;
    return dictionary[key] ?? _values['en']![key] ?? key;
  }
}
