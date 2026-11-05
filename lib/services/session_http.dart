// =============================================================================
// FILE: lib/services/session_http.dart
// Drop-in replacement for `package:http/http.dart` used by ApiService.
//
// Every request goes through one client that watches authenticated responses.
// When the server says the session has ended (expired or invalid token), it
// calls [sessionEndedHook] so the app can sign the user out in one place,
// instead of each screen showing a generic error.
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http_pkg;

export 'package:http/http.dart' hide get, post, put, patch, delete;

/// Called with the token the failed request was sent with.
void Function(String? requestToken)? sessionEndedHook;

/// True when a response means the establishment token is no longer valid.
/// Newer servers answer 401 with a `code`; older ones answered 403 with the
/// message "Invalid or expired token".
bool isSessionEndedResponse(int statusCode, String body) {
  if (statusCode != 401 && statusCode != 403) return false;
  try {
    final data = jsonDecode(body);
    if (data is! Map) return false;
    final code = data['code'];
    if (statusCode == 401 && (code == 'SESSION_EXPIRED' || code == 'SESSION_INVALID')) {
      return true;
    }
    return statusCode == 403 && data['error'] == 'Invalid or expired token';
  } catch (_) {
    return false;
  }
}

String? _bearerToken(http_pkg.BaseRequest request) {
  final header = request.headers['Authorization'] ?? request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  return header.substring(7);
}

class SessionAwareClient extends http_pkg.BaseClient {
  SessionAwareClient([http_pkg.Client? inner]) : _inner = inner ?? http_pkg.Client();

  final http_pkg.Client _inner;

  @override
  Future<http_pkg.StreamedResponse> send(http_pkg.BaseRequest request) async {
    final response = await _inner.send(request);
    final token = _bearerToken(request);
    final status = response.statusCode;
    if (token == null || (status != 401 && status != 403)) return response;

    // Only error responses are buffered, so large downloads still stream.
    final Uint8List bytes = await response.stream.toBytes();
    if (isSessionEndedResponse(status, utf8.decode(bytes, allowMalformed: true))) {
      sessionEndedHook?.call(token);
    }
    return http_pkg.StreamedResponse(
      http_pkg.ByteStream.fromBytes(bytes),
      status,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

/// Shared client for all API calls.
final http_pkg.Client sessionClient = SessionAwareClient();

Future<http_pkg.Response> get(Uri url, {Map<String, String>? headers}) =>
    sessionClient.get(url, headers: headers);

Future<http_pkg.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    sessionClient.post(url, headers: headers, body: body, encoding: encoding);

Future<http_pkg.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    sessionClient.put(url, headers: headers, body: body, encoding: encoding);

Future<http_pkg.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    sessionClient.patch(url, headers: headers, body: body, encoding: encoding);

Future<http_pkg.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    sessionClient.delete(url, headers: headers, body: body, encoding: encoding);
