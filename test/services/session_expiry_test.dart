import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idetect/services/api_service.dart';
import 'package:idetect/services/session_http.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt(int expSeconds) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'exp': expSeconds})}.sig';
}

void main() {
  final now = DateTime.utc(2026, 11, 5, 12);
  int secondsFromNow(int seconds) =>
      now.add(Duration(seconds: seconds)).millisecondsSinceEpoch ~/ 1000;

  group('ApiService.isTokenExpired', () {
    test('is false before the expiry time', () {
      expect(ApiService.isTokenExpired(_jwt(secondsFromNow(60)), now: now), isFalse);
    });

    test('is true at and after the expiry time', () {
      expect(ApiService.isTokenExpired(_jwt(secondsFromNow(0)), now: now), isTrue);
      expect(ApiService.isTokenExpired(_jwt(secondsFromNow(-3600)), now: now), isTrue);
    });

    test('leaves unreadable tokens for the server to judge', () {
      expect(ApiService.isTokenExpired('not-a-jwt', now: now), isFalse);
    });
  });

  group('ApiService.hasExpiredToken', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(ApiService.clearToken);

    test('keeps an expired login so offline scanning still works', () {
      ApiService.setToken(_jwt(secondsFromNow(-3600)));

      expect(ApiService.hasExpiredToken, isTrue);
      expect(ApiService.isLoggedIn, isTrue);
    });

    test('is false for a valid login and after sign out', () {
      ApiService.setToken(_jwt(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600));
      expect(ApiService.hasExpiredToken, isFalse);

      ApiService.clearToken();
      expect(ApiService.hasExpiredToken, isFalse);
      expect(ApiService.isLoggedIn, isFalse);
    });
  });

  group('isSessionEndedResponse', () {
    test('recognises the 401 session codes', () {
      expect(
        isSessionEndedResponse(401, jsonEncode({'code': 'SESSION_EXPIRED'})),
        isTrue,
      );
      expect(
        isSessionEndedResponse(401, jsonEncode({'code': 'SESSION_INVALID'})),
        isTrue,
      );
    });

    test('recognises the older 403 expired-token answer', () {
      expect(
        isSessionEndedResponse(403, jsonEncode({'error': 'Invalid or expired token'})),
        isTrue,
      );
    });

    test('does not treat a wrong password or other 401/403 as session end', () {
      expect(
        isSessionEndedResponse(401, jsonEncode({'error': 'Current password is incorrect'})),
        isFalse,
      );
      expect(
        isSessionEndedResponse(403, jsonEncode({'error': 'Establishment account is not active'})),
        isFalse,
      );
      expect(isSessionEndedResponse(200, jsonEncode({'code': 'SESSION_EXPIRED'})), isFalse);
      expect(isSessionEndedResponse(401, 'not json'), isFalse);
    });
  });

  group('SessionAwareClient', () {
    tearDown(() => sessionEndedHook = null);

    test('reports the token when the server ends the session and keeps the body readable', () async {
      String? reported;
      sessionEndedHook = (token) => reported = token;
      final client = SessionAwareClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Invalid or expired token', 'code': 'SESSION_EXPIRED'}),
            401,
          ),
        ),
      );

      final response = await client.get(
        Uri.parse('https://example.test/api/verification/history'),
        headers: {'Authorization': 'Bearer abc'},
      );

      expect(reported, 'abc');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body)['code'], 'SESSION_EXPIRED');
    });

    test('ignores session-looking errors on requests without a token', () async {
      var called = false;
      sessionEndedHook = (_) => called = true;
      final client = SessionAwareClient(
        MockClient(
          (_) async => http.Response(jsonEncode({'code': 'SESSION_EXPIRED'}), 401),
        ),
      );

      await client.get(Uri.parse('https://example.test/api/auth/establishment/login'));

      expect(called, isFalse);
    });
  });
}
