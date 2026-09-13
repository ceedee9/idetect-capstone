import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/local/local_database.dart';

class ApiService {
  // Set with --dart-define=IDETECT_API_BASE_URL=https://your-host/api.
  // This app intentionally has no hardcoded fallback so the backend target
  // is always explicit.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'IDETECT_API_BASE_URL',
  );
  static String get baseUrl {
    if (_configuredBaseUrl.isEmpty) {
      throw StateError(
        'Missing IDETECT_API_BASE_URL. Pass --dart-define=IDETECT_API_BASE_URL=https://your-host/api when running or building the app.',
      );
    }
    return _configuredBaseUrl;
  }

  static const String _tokenKey = 'idetect_auth_token';
  static const String _userKey = 'idetect_auth_user';

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // ── Token persistence ──────────────────────────────────────────────────────

  static Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = Map<String, dynamic>.from(jsonDecode(userJson));
      }
      if (_token != null) {
        debugPrint('🔑 Beneficiary token restored.');
      }
    } catch (e) {
      debugPrint('⚠️ Could not load token: $e');
    }
  }

  static void setToken(String token, {Map<String, dynamic>? user}) {
    _token = token;
    _persistToken(token);
    if (user != null) {
      _currentUser = user;
      _persistUser(user);
    }
  }

  static void clearToken() {
    _token = null;
    _currentUser = null;
    _removeToken();
    _removeUser();
  }

  static bool get isLoggedIn => _token != null;

  /// Raw token string, for callers (e.g. status_sync_service.dart) that need
  /// to build their own Authorization header outside of _authHeaders().
  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;

  static Future<void> _persistToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('⚠️ Could not persist token: $e');
    }
  }

  static Future<void> _removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  static Future<void> _persistUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (_) {}
  }

  static Future<void> _removeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  static Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // ── Establishment Login (email + password) ────────────────────────────────
  //
  // Calls POST /auth/establishment/login. auth.js sends every failure case
  // here (bad credentials, pending/suspended/revoked status, lockout)
  // through createError(), which errorHandler.js always serializes as
  // {error: '...'} — so unlike change-password, there's no second shape to
  // branch on for the route's own failures. The only exception is
  // express-validator rejecting a malformed email before the route body
  // runs, which comes back as {errors: [{msg: '...'}]} instead.
  //
  // On success the response is {token, establishment: {...}, user: {id,
  // name, full_name, email, role}} — the `user` object already matches
  // what AccountProfileDrawer reads (name/full_name, email, role), so it's
  // stored as-is.

  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/establishment/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        setToken(
          data['token'],
          user: data['user'] != null
              ? Map<String, dynamic>.from(data['user'])
              : null,
        );
        return LoginResult(success: true);
      }

      final errors = data['errors'];
      String message;
      if (errors is List && errors.isNotEmpty) {
        message = errors.first['msg']?.toString() ?? 'Invalid input.';
      } else {
        message = data['error'] ??
            data['message'] ??
            'Login failed. Please try again.';
      }
      return LoginResult(success: false, errorMessage: message);
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  // ── Auth (OTP) ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> requestOtp({
    required String idNumber,
    required String birthdate,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/beneficiary/request-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_number': idNumber, 'birthdate': birthdate}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  /// Register a mobile number for first-time beneficiaries.
  /// Returns the API response map (may contain mobile_registered: true).
  static Future<Map<String, dynamic>> registerMobile({
    required String idNumber,
    required String birthdate,
    required String mobileNumber,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/beneficiary/register-mobile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_number': idNumber,
              'birthdate': birthdate,
              'mobile_number': mobileNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        return {
          'error': data['error'] ?? data['message'] ?? 'Registration failed',
        };
      }
      return data;
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  static Future<BeneficiaryAuthResult> verifyOtp({
    required String idNumber,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/beneficiary/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_number': idNumber, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['token'] != null) {
        setToken(
          data['token'],
          user: {...?data['beneficiary'], 'type': 'beneficiary'},
        );
        return BeneficiaryAuthResult(
          success: true,
          fullName: data['beneficiary']?['full_name'],
          beneficiaryType: data['beneficiary']?['beneficiary_type'],
        );
      }
      return BeneficiaryAuthResult(
        success: false,
        errorMessage:
            data['error'] ?? data['message'] ?? 'OTP verification failed',
      );
    } catch (e) {
      return BeneficiaryAuthResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  // ── PIN Management ─────────────────────────────────────────────────────────

  /// Set a 4-digit PIN for fallback login (requires auth token).
  static Future<Map<String, dynamic>> setPin(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/beneficiary/set-pin'),
            headers: _authHeaders(),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        return {
          'error': data['error'] ?? data['message'] ?? 'Failed to set PIN',
        };
      }
      return data;
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  /// Login with ID number + 4-digit PIN.
  static Future<BeneficiaryAuthResult> loginWithPin({
    required String idNumber,
    required String pin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/beneficiary/login-pin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_number': idNumber, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['token'] != null) {
        setToken(
          data['token'],
          user: {...?data['beneficiary'], 'type': 'beneficiary'},
        );
        return BeneficiaryAuthResult(
          success: true,
          fullName: data['beneficiary']?['full_name'],
          beneficiaryType: data['beneficiary']?['beneficiary_type'],
        );
      }
      return BeneficiaryAuthResult(
        success: false,
        errorMessage: data['error'] ?? data['message'] ?? 'PIN login failed',
      );
    } catch (e) {
      return BeneficiaryAuthResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  // ── Establishment Password Change (authenticated, current-password required) ─
  //
  // Calls POST /auth/establishment/change-password. On success the backend
  // just returns {message: '...'} with a 200 — there's no `success` key on
  // the wire, so status code 200 IS the success signal here.
  //
  // Failure shapes, per errorHandler.js + auth.js:
  //   - Most failures (wrong current password, same-password check, expired/
  //     invalid token) go through createError() and land as {error: '...'}.
  //   - The one exception: express-validator rejecting new_password before
  //     the route body even runs (e.g. under 8 chars) returns
  //     {errors: [{msg: '...'}]} instead — a different shape.
  //
  // A 401 specifically means the establishment JWT is missing/expired, not
  // that the current password was wrong (that's handled inside the route
  // body and comes back as a normal {error: '...'} 401 from createError —
  // see the note in change_password_screen.dart's _submit() for how the two
  // are told apart). We clear the stored token here either way, since a 401
  // means it's no longer valid.

  static Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/establishment/change-password'),
            headers: _authHeaders(),
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ChangePasswordResult(success: true);
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 401) {
        // Token missing/invalid/expired — establishment needs to log back
        // in. Clear the stale token so isLoggedIn flips false right away.
        clearToken();
        return ChangePasswordResult(
          success: false,
          sessionExpired: true,
          errorMessage: 'Your session has expired. Please log in again.',
        );
      }

      final errors = data['errors'];
      String message;
      if (errors is List && errors.isNotEmpty) {
        message = errors.first['msg']?.toString() ?? 'Invalid input.';
      } else {
        message = data['error'] ?? 'Could not update password.';
      }
      return ChangePasswordResult(success: false, errorMessage: message);
    } catch (e) {
      return ChangePasswordResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  // ── Verification History (REQ-2.16.5) ─────────────────────────────────────
  //
  // Calls GET /verification/history. The route originally only read `page`
  // and `limit` — start_date/end_date/result were being sent by
  // history_screen.dart but silently ignored server-side, so the date-range
  // and result-type filters in that screen did nothing. verification.js's
  // /history route now accepts start_date (inclusive), end_date (inclusive,
  // via < end_date + 1 day), and result (one of valid/suspicious/invalid/
  // manual_review) — see that file for the SQL. This method just forwards
  // whichever of those the screen supplies.
  //
  // Note the summary-counts caller (_loadSummary in history_screen.dart)
  // still fetches up to 10,000 rows and counts client-side rather than the
  // backend returning aggregate counts directly — fine for now, but worth
  // moving server-side if establishments start accumulating more scans than
  // that in a filtered range.

  static Future<Map<String, dynamic>> getVerificationHistory({
    required int page,
    required int limit,
    String? startDate,
    String? endDate,
    String? resultFilter,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (resultFilter != null) 'result': resultFilter,
      };
      final uri = Uri.parse('$baseUrl/verification/history')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data; // {data: [...], pagination: {...}}
      }
      return {
        'error': data['error'] ??
            data['message'] ??
            'Failed to load verification history.',
      };
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  // ── ID Verification (scan) ─────────────────────────────────────────────────
  //
  // Calls POST /verification/scan. The image is sent as base64 in the JSON
  // body (image_data), matching verification.js — not multipart, unlike
  // uploadDisputeDoc. Failure to read/encode the image is non-fatal; the scan
  // still proceeds without image_data (backend just skips the upload step).

  static Future<VerificationResult> verifyId({
    required String idNumber,
    required String beneficiaryType,
    num? ocrConfidence,
    required String imagePath,
    bool manuallyEntered = false,
    String? extractedName,
    String? extractedDob,
    String idFormat = 'old',
    bool? sealDetected,
  }) async {
    // ── Fast local block (REQ-2.9.1) ────────────────────────────────────────
    // If the last status sync already flagged this ID as revoked/suspended,
    // reject instantly without waiting on the network. This is a FAST BLOCK
    // ONLY, never a fast approve: a cache miss (null) or 'active' always
    // falls through to the real server call below. That asymmetry matters —
    // staleness can only ever make a block arrive a few seconds late, never
    // make an approval arrive early on stale data.
    //
    // The instant result is returned to the cashier immediately, but the
    // real server call still happens in the background (fire-and-forget) so
    // this attempt still lands in verification_logs for establishment
    // history/analytics — just without making the cashier wait for it.
    final cachedStatus = await LocalDatabase.getCachedStatus(idNumber);
    if (cachedStatus == 'revoked' || cachedStatus == 'suspended') {
      final instant = VerificationResult(
        status: cachedStatus == 'revoked'
            ? VerificationStatus.invalid
            : VerificationStatus.suspicious,
        message: cachedStatus == 'revoked'
            ? 'This ID has been reported and confirmed fraudulent.'
            : 'This ID is currently under investigation.',
      );

      unawaited(_callVerifyEndpoint(
        idNumber: idNumber,
        beneficiaryType: beneficiaryType,
        ocrConfidence: ocrConfidence,
        imagePath: imagePath,
        manuallyEntered: manuallyEntered,
        extractedName: extractedName,
        extractedDob: extractedDob,
        idFormat: idFormat,
        sealDetected: sealDetected,
      ));

      return instant;
    }

    return _callVerifyEndpoint(
      idNumber: idNumber,
      beneficiaryType: beneficiaryType,
      ocrConfidence: ocrConfidence,
      imagePath: imagePath,
      manuallyEntered: manuallyEntered,
      extractedName: extractedName,
      extractedDob: extractedDob,
      idFormat: idFormat,
      sealDetected: sealDetected,
    );
  }

  /// The actual network call to POST /verification/scan. Called normally
  /// (awaited) for a fresh scan, or fire-and-forget after an instant local
  /// block above — in that second case its return value is discarded; it
  /// only exists to make sure the attempt still gets logged server-side.
  static Future<VerificationResult> _callVerifyEndpoint({
    required String idNumber,
    required String beneficiaryType,
    num? ocrConfidence,
    required String imagePath,
    bool manuallyEntered = false,
    String? extractedName,
    String? extractedDob,
    String idFormat = 'old',
    bool? sealDetected,
  }) async {
    String? imageBase64;
    try {
      final bytes = await File(imagePath).readAsBytes();
      imageBase64 = base64Encode(bytes);
    } catch (e) {
      debugPrint('⚠️ Could not read ID image for upload: $e');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verification/scan'),
            headers: _authHeaders(),
            body: jsonEncode({
              'id_number': idNumber,
              'beneficiary_type': beneficiaryType,
              if (ocrConfidence != null)
                'ocr_confidence_score': normalizeConfidenceScore(ocrConfidence),
              if (imageBase64 != null) 'image_data': imageBase64,
              'manually_entered': manuallyEntered,
              if (extractedName != null && extractedName.isNotEmpty)
                'extracted_name': extractedName,
              if (extractedDob != null && extractedDob.isNotEmpty)
                'extracted_dob': extractedDob,
              'id_format': idFormat,
              if (sealDetected != null) 'seal_detected': sealDetected,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['result'] != null) {
        return VerificationResult(
          status: _statusFromString(data['result']),
          message: data['message'],
          verificationId: data['verification_id'],
          beneficiaryName: data['beneficiary']?['full_name'],
        );
      }

      final errors = data['errors'];
      String message;
      if (errors is List && errors.isNotEmpty) {
        message = errors.first['msg']?.toString() ?? 'Invalid input.';
      } else {
        message = data['message'] ?? data['error'] ?? 'Verification failed.';
      }
      return VerificationResult(
        status: VerificationStatus.error,
        errorMessage: message,
      );
    } on TimeoutException catch (_) {
      return _unreachableResult();
    } on SocketException catch (_) {
      return _unreachableResult();
    } on http.ClientException catch (_) {
      return _unreachableResult();
    } catch (e) {
      return VerificationResult(
        status: VerificationStatus.error,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  /// Built when the server genuinely can't be reached (timeout, no socket,
  /// connection refused) — distinct from a reachable server returning an
  /// error. isOffline:true is what result_screen.dart checks to decide
  /// whether to call OfflineScanSyncService.queueOfflineScan.
  static VerificationResult _unreachableResult() {
    return VerificationResult(
      status: VerificationStatus.manualReview,
      message:
          'No internet connection. This scan has been saved and will be verified automatically once you\'re back online.',
      isOffline: true,
    );
  }

  /// Converts a 0.0-1.0 OCR confidence fraction (how ParsedIDData.confidence
  /// is stored) into the 0-100 scale verification.js expects
  /// (isFloat({min:0,max:100}) plus its "< threshold%" low-confidence check).
  /// Public and shared: offline_scan_sync_service.dart calls this too, so the
  /// live-scan path and the offline-replay path can never drift apart again
  /// the way they did before (live scans were sending unscaled 0.0-1.0
  /// values, which the server read as ~0-1% confidence and flagged as low
  /// quality on nearly every scan).
  static double normalizeConfidenceScore(num raw) {
    final value = raw.toDouble();
    return (value <= 1.0 ? value * 100.0 : value).clamp(0.0, 100.0);
  }

  static VerificationStatus _statusFromString(String value) {
    switch (value) {
      case 'valid':
        return VerificationStatus.valid;
      case 'suspicious':
        return VerificationStatus.suspicious;
      case 'invalid':
        return VerificationStatus.invalid;
      case 'manual_review':
        return VerificationStatus.manualReview;
      default:
        return VerificationStatus.error;
    }
  }

  // ── Cashier Action Logging (Gap 8) ─────────────────────────────────────────
  //
  // Calls POST /verification/:id/cashier-action. Fire-and-forget from the
  // caller's side (result_screen.dart chains .catchError((_) {})), so this
  // just returns a bool rather than throwing.

  static Future<bool> logCashierAction({
    required String verificationId,
    required String action,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verification/$verificationId/cashier-action'),
            headers: _authHeaders(),
            body: jsonEncode({'action': action}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Fraud Flags (REQ-2.6.4) ─────────────────────────────────────────────────
  //
  // Calls POST /fraud-flags. Returns a raw Map rather than a typed result,
  // matching the pattern fraud_flag_sync_service.dart already expects:
  // success → the response fields as-is; failure → {'error': message}, which
  // is what submitFlagNow()/syncPendingFlags() check to decide whether to
  // queue the flag offline instead.

  static Future<Map<String, dynamic>> reportFraudFlag({
    required String verificationLogId,
    required String idNumberFlagged,
    required String beneficiaryType,
    String? notes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/fraud-flags'),
            headers: _authHeaders(),
            body: jsonEncode({
              'verification_log_id': verificationLogId,
              'id_number_flagged': idNumberFlagged,
              'beneficiary_type': beneficiaryType,
              if (notes != null && notes.isNotEmpty)
                'establishment_notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'message': data['message'],
          'flag_id': data['flag_id'],
          'is_supplementary': data['is_supplementary'],
          'parent_flag_id': data['parent_flag_id'],
          'auto_suspended': data['auto_suspended'],
        };
      }

      final errors = data['errors'];
      String message;
      if (errors is List && errors.isNotEmpty) {
        message = errors.first['msg']?.toString() ?? 'Invalid input.';
      } else {
        message =
            data['message'] ?? data['error'] ?? 'Failed to submit fraud flag.';
      }
      return {'error': message};
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  // ── Profile / ID Status (REQ-2.12) ────────────────────────────────────────

  static Future<BeneficiaryProfile?> getProfile() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/beneficiary-portal/me'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return BeneficiaryProfile.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Transaction History ────────────────────────────────────────────────────

  static Future<TransactionListResult> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/beneficiary-portal/transactions?page=$page&limit=$limit',
            ),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final items = (data['data'] as List)
            .map((e) => TransactionRecord.fromJson(e))
            .toList();
        return TransactionListResult(
          success: true,
          transactions: items,
          total: data['pagination']?['total'] ?? items.length,
        );
      }
      return TransactionListResult(
        success: false,
        errorMessage: data['error'] ?? 'Failed to load transactions.',
      );
    } catch (e) {
      return TransactionListResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  static Future<NotificationListResult> getNotifications({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications?page=$page&limit=$limit'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final items = (data['data'] as List)
            .map((e) => AppNotification.fromJson(e))
            .toList();
        return NotificationListResult(
          success: true,
          notifications: items,
          total: data['pagination']?['total'] ?? items.length,
        );
      }
      return NotificationListResult(
        success: false,
        errorMessage: data['error'] ?? 'Failed to load notifications.',
      );
    } catch (e) {
      return NotificationListResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications/unread-count'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['unread'] ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/$notificationId/read'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/read-all'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> reportUnauthorizedUse({
    required String verificationLogId,
    String? statement,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/notifications/unauthorized-use'),
            headers: _authHeaders(),
            body: jsonEncode({
              'verification_log_id': verificationLogId,
              if (statement != null) 'statement': statement,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  // ── Disputes ───────────────────────────────────────────────────────────────

  static Future<DisputeListResult> getMyDisputes({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/disputes/mine?page=$page&limit=$limit'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final items = (data['data'] as List)
            .map((e) => DisputeRecord.fromJson(e))
            .toList();
        return DisputeListResult(
          success: true,
          disputes: items,
          total: data['pagination']?['total'] ?? items.length,
        );
      }
      return DisputeListResult(
        success: false,
        errorMessage: data['error'] ?? 'Failed to load disputes.',
      );
    } catch (e) {
      return DisputeListResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  static Future<Map<String, dynamic>> submitDispute({
    String? verificationLogId,
    required String disputeType,
    required String explanation,
    String? supportingDocPath,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/disputes'),
            headers: _authHeaders(),
            body: jsonEncode({
              if (verificationLogId != null)
                'verification_log_id': verificationLogId,
              'dispute_type': disputeType,
              'explanation': explanation,
              if (supportingDocPath != null)
                'supporting_doc_path': supportingDocPath,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return data;
      }
      // Surface the actual error from the API response
      final errors = data['errors'] as List?;
      final msg = errors != null && errors.isNotEmpty
          ? errors.map((e) => e['msg'] ?? e.toString()).join(', ')
          : data['message'] ??
              data['error'] ??
              'Submission failed (${response.statusCode})';
      return {'error': msg};
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  /// Upload a supporting document for a dispute.
  /// Returns `{'path': '/uploads/dispute-docs/...'}` on success,
  /// or `{'error': '...'}` on failure.
  static Future<Map<String, dynamic>> uploadDisputeDoc(String filePath) async {
    try {
      final uri = Uri.parse('$baseUrl/disputes/upload-doc');
      final request = http.MultipartRequest('POST', uri);
      // Auth header (without Content-Type — multipart sets its own)
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(
        await http.MultipartFile.fromPath('document', filePath),
      );

      final streamed = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);

      if (streamed.statusCode == 200) {
        return data; // { path: '...' }
      }
      return {
        'error': data['error'] ?? 'Upload failed (${streamed.statusCode})',
      };
    } catch (e) {
      return {'error': 'Cannot upload file: $e'};
    }
  }

  // ── Device Token (FCM) ────────────────────────────────────────────────────

  /// Registers or refreshes the FCM device token with the API.
  /// Called after login and when FCM issues a new token.
  static Future<void> registerDeviceToken(String token) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/beneficiary-portal/device-token'),
            headers: _authHeaders(),
            body: jsonEncode({'device_token': token}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('🔔 FCM token registered: ${response.statusCode}');
    } catch (e) {
      debugPrint('🔔 FCM token register error: $e');
    }
  }

  // ── Fraud Report (REQ-2.14) ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitFraudReport({
    String? verificationLogId,
    required String reportType,
    required String description,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/beneficiary-portal/fraud-report'),
            headers: _authHeaders(),
            body: jsonEncode({
              if (verificationLogId != null)
                'verification_log_id': verificationLogId,
              'report_type': reportType,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class BeneficiaryAuthResult {
  final bool success;
  final String? fullName;
  final String? beneficiaryType;
  final String? errorMessage;

  BeneficiaryAuthResult({
    required this.success,
    this.fullName,
    this.beneficiaryType,
    this.errorMessage,
  });
}

class LoginResult {
  final bool success;
  final String? errorMessage;

  LoginResult({required this.success, this.errorMessage});
}

enum VerificationStatus { valid, suspicious, invalid, manualReview, error }

class VerificationResult {
  final VerificationStatus status;
  final String? message;
  final String? verificationId;
  final String? beneficiaryName;
  final String? errorMessage;
  final bool isOffline;
  final DateTime? offlineSyncedAt;

  VerificationResult({
    required this.status,
    this.message,
    this.verificationId,
    this.beneficiaryName,
    this.errorMessage,
    this.isOffline = false,
    this.offlineSyncedAt,
  });

  String get displayStatus {
    switch (status) {
      case VerificationStatus.valid:
        return 'VALID';
      case VerificationStatus.suspicious:
        return 'SUSPICIOUS';
      case VerificationStatus.invalid:
        return 'INVALID';
      case VerificationStatus.manualReview:
        return 'MANUAL REVIEW';
      case VerificationStatus.error:
        return 'ERROR';
    }
  }
}

class ChangePasswordResult {
  final bool success;
  final String? errorMessage;
  final bool sessionExpired;

  ChangePasswordResult({
    required this.success,
    this.errorMessage,
    this.sessionExpired = false,
  });
}

class BeneficiaryProfile {
  final String id;
  final String idNumber;
  final String fullName;
  final String birthdate;
  final String beneficiaryType;
  final String issuingOffice;
  final String validityStart;
  final String validityEnd;
  final String status;
  final String? statusReason;
  final String? registeredMobile;
  final int totalVerifications;
  final int pendingFlags;
  final int activeDisputes;

  BeneficiaryProfile({
    required this.id,
    required this.idNumber,
    required this.fullName,
    required this.birthdate,
    required this.beneficiaryType,
    required this.issuingOffice,
    required this.validityStart,
    required this.validityEnd,
    required this.status,
    this.statusReason,
    this.registeredMobile,
    this.totalVerifications = 0,
    this.pendingFlags = 0,
    this.activeDisputes = 0,
  });

  factory BeneficiaryProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return BeneficiaryProfile(
      id: json['id'],
      idNumber: json['id_number'],
      fullName: json['full_name'],
      birthdate: json['birthdate']?.toString().substring(0, 10) ?? '',
      beneficiaryType: json['beneficiary_type'],
      issuingOffice: json['issuing_office'],
      validityStart: json['validity_start']?.toString().substring(0, 10) ?? '',
      validityEnd: json['validity_end']?.toString().substring(0, 10) ?? '',
      status: json['status'],
      statusReason: json['status_reason'],
      registeredMobile: json['registered_mobile'],
      totalVerifications: stats['total_verifications'] ?? 0,
      pendingFlags: stats['pending_flags'] ?? 0,
      activeDisputes: stats['active_disputes'] ?? 0,
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
  bool get isSuspended => status == 'suspended';
  bool get isRevoked => status == 'revoked';

  /// Days remaining until the ID expires. Negative means already expired.
  int? get daysUntilExpiry {
    if (validityEnd.isEmpty) return null;
    try {
      final end = DateTime.parse(validityEnd);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      return end.difference(todayDate).inDays;
    } catch (_) {
      return null;
    }
  }
}

class TransactionRecord {
  final String id;
  final String result;
  final double? ocrConfidence;
  final bool manuallyEntered;
  final DateTime verifiedAt;
  final String? establishmentName;
  final String? establishmentAddress;

  TransactionRecord({
    required this.id,
    required this.result,
    this.ocrConfidence,
    required this.manuallyEntered,
    required this.verifiedAt,
    this.establishmentName,
    this.establishmentAddress,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'],
      result: json['result'] ?? 'unknown',
      ocrConfidence: json['ocr_confidence_score'] != null
          ? double.tryParse(json['ocr_confidence_score'].toString())
          : null,
      manuallyEntered: json['manually_entered'] ?? false,
      verifiedAt: DateTime.parse(json['verified_at']),
      establishmentName: json['establishment_name'],
      establishmentAddress: json['establishment_address'],
    );
  }

  String get displayResult => result.toUpperCase().replaceAll('_', ' ');
}

class TransactionListResult {
  final bool success;
  final List<TransactionRecord> transactions;
  final int total;
  final String? errorMessage;

  TransactionListResult({
    required this.success,
    this.transactions = const [],
    this.total = 0,
    this.errorMessage,
  });
}

class AppNotification {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final String channel;
  final String? verificationLogId;
  final String? disputeId;
  final bool isRead;
  final DateTime sentAt;
  final String? verificationResult;
  final DateTime? verificationTime;
  final String? establishmentName;

  AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.channel,
    this.verificationLogId,
    this.disputeId,
    required this.isRead,
    required this.sentAt,
    this.verificationResult,
    this.verificationTime,
    this.establishmentName,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      notificationType: json['notification_type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      channel: json['channel'] ?? 'push',
      verificationLogId: json['verification_log_id'],
      disputeId: json['dispute_id'],
      isRead: json['is_read'] ?? false,
      sentAt: DateTime.parse(json['sent_at']),
      verificationResult: json['verification_result'],
      verificationTime: json['verification_time'] != null
          ? DateTime.parse(json['verification_time'])
          : null,
      establishmentName: json['establishment_name'],
    );
  }
}

class NotificationListResult {
  final bool success;
  final List<AppNotification> notifications;
  final int total;
  final String? errorMessage;

  NotificationListResult({
    required this.success,
    this.notifications = const [],
    this.total = 0,
    this.errorMessage,
  });
}

class DisputeRecord {
  final String id;
  final String disputeType;
  final String explanation;
  final String status;
  final String? resolution;
  final DateTime submittedAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final String? verificationResult;
  final String? establishmentName;

  DisputeRecord({
    required this.id,
    required this.disputeType,
    required this.explanation,
    required this.status,
    this.resolution,
    required this.submittedAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.verificationResult,
    this.establishmentName,
  });

  factory DisputeRecord.fromJson(Map<String, dynamic> json) {
    return DisputeRecord(
      id: json['id'],
      disputeType: json['dispute_type'] ?? '',
      explanation: json['explanation'] ?? '',
      status: json['status'] ?? 'submitted',
      resolution: json['resolution'],
      submittedAt: DateTime.parse(json['submitted_at'] ?? json['created_at']),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      verificationResult: json['verification_result'],
      establishmentName: json['establishment_name'],
    );
  }

  String get displayType => disputeType.replaceAll('_', ' ').toUpperCase();
  String get reference => id.substring(0, 8).toUpperCase();
}

class DisputeListResult {
  final bool success;
  final List<DisputeRecord> disputes;
  final int total;
  final String? errorMessage;

  DisputeListResult({
    required this.success,
    this.disputes = const [],
    this.total = 0,
    this.errorMessage,
  });
}
