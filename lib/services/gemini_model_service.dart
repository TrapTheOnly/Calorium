import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiModelService {
  static const String _host = 'generativelanguage.googleapis.com';
  static const List<String> _fallbackModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest'
  ];

  /// Fetches Gemini models that support content generation for the provided API key.
  static Future<List<String>> fetchAvailableModels(String apiKey) async {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    try {
      final models = await _fetchModelsFromApi(apiKey);
      if (models.isEmpty) {
        return [..._fallbackModels]..sort();
      }
      return models;
    } catch (error) {
      if (_isCertificateNotYetValidError(error)) {
        throw GeminiModelFetchException(
          'Secure connection to Google AI failed because the TLS certificate is not yet valid. This usually means the device date/time is incorrect.',
          fallbackModels: [..._fallbackModels]..sort(),
        );
      }
      rethrow;
    }
  }

  static Future<List<String>> _fetchModelsFromApi(String apiKey) async {
    final modelNames = <String>{};
    String? pageToken;

    do {
      final queryParameters = <String, String>{
        'key': apiKey,
        'pageSize': '100',
        if (pageToken != null) 'pageToken': pageToken,
      };

      final uri = Uri.https(_host, '/v1/models', queryParameters);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response.body, response.statusCode));
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Unexpected response from Gemini models endpoint',
        );
      }

      final models = decoded['models'];
      if (models is List) {
        for (final model in models) {
          if (model is! Map<String, dynamic>) continue;

          final name = model['name'];
          if (name is! String || !name.contains('models/gemini')) continue;

          final supported = model['supportedGenerationMethods'];
          if (supported is List && !supported.contains('generateContent')) {
            continue;
          }

          final state = model['state'];
          if (state is String && state.toUpperCase() == 'DEPRECATED') continue;

          final normalizedName =
              name.startsWith('models/') ? name.substring(7) : name;
          if (normalizedName.isNotEmpty) {
            modelNames.add(normalizedName);
          }
        }
      }

      final nextPageToken = decoded['nextPageToken'];
      pageToken =
          nextPageToken is String && nextPageToken.isNotEmpty
              ? nextPageToken
              : null;
    } while (pageToken != null);

    return modelNames.toList()..sort();
  }

  static bool _isCertificateNotYetValidError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('certificate') && message.contains('not yet valid');
  }

  static String _parseError(String body, int statusCode) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) {
            return '($statusCode) $message';
          }
        }
      }
    } catch (_) {
      // Ignore parsing errors and fall back to generic message below.
    }
    return '($statusCode) Failed to retrieve Gemini models';
  }
}

class GeminiModelFetchException implements Exception {
  final String message;
  final List<String> fallbackModels;

  GeminiModelFetchException(this.message, {this.fallbackModels = const []});

  @override
  String toString() => message;
}
