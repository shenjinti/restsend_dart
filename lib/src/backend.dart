import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utils.dart';

/// Backend API exception
class BackendException implements Exception {
  final String message;
  final int? statusCode;

  BackendException(this.message, [this.statusCode]);

  @override
  String toString() => 'BackendException: $message (code: $statusCode)';
}

/// Handle HTTP response
Future<dynamic> handleResult(http.Response resp) async {
  if (resp.statusCode != 200) {
    String reason = resp.body;
    try {
      if (resp.headers['content-type']?.contains('json') ?? false) {
        final data = jsonDecode(reason);
        reason = data['error'] ?? reason;
      }
    } catch (e) {
      // ignore json parse error
    }
    if (reason.isEmpty) {
      reason = resp.reasonPhrase ?? 'Unknown error';
    }
    throw BackendException(reason, resp.statusCode);
  }
  return jsonDecode(resp.body);
}

/// Send HTTP request
Future<dynamic> sendReq(
  String method,
  String url,
  dynamic data,
  String? token,
) async {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };

  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  http.Response response;

  try {
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(Uri.parse(url), headers: headers);
        break;
      case 'POST':
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          Uri.parse(url),
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          Uri.parse(url),
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(
          Uri.parse(url),
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        );
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    return await handleResult(response);
  } catch (e) {
    logger.severe('HTTP request failed: $e');
    rethrow;
  }
}

/// Backend API client
class BackendApi {
  final String? token;

  BackendApi(this.token);

  Future<dynamic> delete(String url, [dynamic data]) async {
    return await sendReq('DELETE', url, data, token);
  }

  Future<dynamic> get(String url) async {
    return await sendReq('GET', url, null, token);
  }

  Future<dynamic> put(String url, dynamic data) async {
    return await sendReq('PUT', url, data, token);
  }

  Future<dynamic> patch(String url, dynamic data) async {
    return await sendReq('PATCH', url, data, token);
  }

  Future<dynamic> post(String url, [dynamic data]) async {
    return await sendReq('POST', url, data, token);
  }
}
