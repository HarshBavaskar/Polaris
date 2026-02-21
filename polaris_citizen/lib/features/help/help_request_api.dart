import 'package:http/http.dart' as http;
import '../../core/api.dart';
import 'help_request.dart';

abstract class HelpRequestApi {
  Future<void> submitHelpRequest(HelpRequest request);
}

class HelpRequestHttpException implements Exception {
  final int statusCode;
  final String message;

  const HelpRequestHttpException(this.statusCode, this.message);
}

class HttpHelpRequestApi implements HelpRequestApi {
  final String baseUrl;
  final http.Client _client;

  HttpHelpRequestApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = client ?? http.Client();

  @override
  Future<void> submitHelpRequest(HelpRequest request) async {
    final Map<String, String> body = <String, String>{
      'category': request.category,
      'contact_number': request.contactNumber,
      if (request.lat != null) 'lat': request.lat!.toString(),
      if (request.lng != null) 'lng': request.lng!.toString(),
    };
    final http.Response response = await _client.post(
      Uri.parse('$baseUrl/input/citizen/help-request'),
      body: body,
    );
    if (response.statusCode != 200) {
      throw HelpRequestHttpException(
        response.statusCode,
        'Failed to submit help request',
      );
    }
  }
}
