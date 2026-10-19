import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _tokenKey = 'beneficiary_auth_token';
  static const String _userKey = 'beneficiary_auth_user';

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

  /// Returns the decoded JSON object, or null when the body is not JSON
  /// (for example a gateway page sent while the API container is starting).
  static Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Login with ID number + 4-digit PIN.
  ///
  /// The API can take several seconds to wake up after idle, and the host may
  /// answer with a non-JSON page until it is ready. Those gateway responses
  /// never reach the PIN check, so they are retried instead of counted.
  static Future<BeneficiaryAuthResult> loginWithPin({
    required String idNumber,
    required String pin,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/auth/beneficiary/login-pin'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'id_number': idNumber, 'pin': pin}),
            )
            .timeout(const Duration(seconds: 25));

        final data = _tryDecodeJsonObject(response.body);
        if (data == null) {
          if (attempt < maxAttempts) {
            await Future<void>.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
          return BeneficiaryAuthResult(
            success: false,
            errorMessage:
                'The server is starting up. Please try again in a moment.',
          );
        }
        return _completePinLogin(response.statusCode, data);
      } catch (e) {
        return BeneficiaryAuthResult(
          success: false,
          errorMessage: 'Cannot reach server: $e',
        );
      }
    }
  }

  static BeneficiaryAuthResult _completePinLogin(
    int statusCode,
    Map<String, dynamic> data,
  ) {
    if (statusCode == 200 && data['token'] != null) {
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

  /// True only when the server has explicitly ended this session because the
  /// account was signed in on another phone. Network errors return false so a
  /// flaky connection never logs the user out.
  static Future<bool> isSessionEnded() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/beneficiary-portal/me'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 401) return false;
      final body = jsonDecode(response.body);
      return body is Map && body['code'] == 'SESSION_ENDED';
    } catch (_) {
      return false;
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

  /// Confirms the beneficiary read the staff response. Returns null on success,
  /// otherwise a message to show the user.
  static Future<String?> acknowledgeDisputeResponse(String disputeId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/disputes/$disputeId/acknowledge-response'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['error'] ?? 'Could not record your acknowledgement.';
    } catch (e) {
      return 'Cannot reach server: $e';
    }
  }

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

  static Future<Map<String, dynamic>> submitCallbackRequest({
    required String establishmentId,
    required String reason,
    String? note,
    String? verificationLogId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/beneficiary-portal/callback-requests'),
            headers: _authHeaders(),
            body: jsonEncode({
              'establishment_id': establishmentId,
              'reason': reason,
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
              if (verificationLogId != null)
                'verification_log_id': verificationLogId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'reference': data['reference']};
      }
      // Status code lets the UI show a localized message for known cases.
      final errors = data['errors'] as List?;
      final msg = errors != null && errors.isNotEmpty
          ? errors.map((e) => e['msg'] ?? e.toString()).join(', ')
          : data['error'] ?? 'Request failed (${response.statusCode})';
      return {'error': msg, 'status': response.statusCode};
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  static Future<CallbackRequestListResult> getMyCallbackRequests() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/beneficiary-portal/callback-requests'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final list = (data['data'] as List? ?? [])
            .map((j) => CallbackRequestRecord.fromJson(j as Map<String, dynamic>))
            .toList();
        return CallbackRequestListResult(success: true, requests: list);
      }
      return CallbackRequestListResult(
        success: false,
        errorMessage: data['error'] ?? 'Failed to load callback requests.',
      );
    } catch (e) {
      return CallbackRequestListResult(
        success: false,
        errorMessage: 'Cannot reach server: $e',
      );
    }
  }

  static Future<Map<String, dynamic>> submitDispute({
    String? verificationLogId,
    required String disputeType,
    required String explanation,
    // NEW: where the incident happened (business/office name). Optional at
    // this layer — disputes_screen.dart only requires it for certain
    // dispute types; the backend decides what it does with a missing value.
    String? establishmentName,
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
              if (establishmentName != null)
                'establishment_name': establishmentName,
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
  final String? suspensionEndDate;
  final int? suspensionDaysRemaining;
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
    this.suspensionEndDate,
    this.suspensionDaysRemaining,
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
      suspensionEndDate: json['suspension_end_date']?.toString(),
      suspensionDaysRemaining: json['suspension_days_remaining'] is num
          ? (json['suspension_days_remaining'] as num).toInt()
          : null,
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
  final String? referenceNo;
  final String result;
  final double? ocrConfidence;
  final bool manuallyEntered;
  final DateTime verifiedAt;
  final String? establishmentId;
  final String? establishmentName;
  final String? establishmentAddress;

  TransactionRecord({
    required this.id,
    this.referenceNo,
    required this.result,
    this.ocrConfidence,
    required this.manuallyEntered,
    required this.verifiedAt,
    this.establishmentId,
    this.establishmentName,
    this.establishmentAddress,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'],
      referenceNo: json['reference_no'],
      result: json['result'] ?? 'unknown',
      ocrConfidence: json['ocr_confidence_score'] != null
          ? double.tryParse(json['ocr_confidence_score'].toString())
          : null,
      manuallyEntered: json['manually_entered'] ?? false,
      verifiedAt: DateTime.parse(json['verified_at']),
      establishmentId: json['establishment_id'],
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
  final String? referenceNo;
  final bool filedOnBehalf;
  final String? filedByEstablishmentName;
  final DateTime? beneficiaryAcknowledgedAt;

  DisputeRecord({
    required this.id,
    this.referenceNo,
    required this.disputeType,
    required this.explanation,
    required this.status,
    this.resolution,
    required this.submittedAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.verificationResult,
    this.establishmentName,
    this.filedOnBehalf = false,
    this.filedByEstablishmentName,
    this.beneficiaryAcknowledgedAt,
  });

  factory DisputeRecord.fromJson(Map<String, dynamic> json) {
    return DisputeRecord(
      id: json['id'],
      referenceNo: json['reference_no'],
      disputeType: json['dispute_type'] ?? '',
      explanation: json['explanation'] ?? '',
      status: json['status'] ?? 'submitted',
      // API returns staff_response; the older 'resolution' key is kept as a fallback.
      resolution: json['staff_response'] ?? json['resolution'],
      submittedAt: DateTime.parse(json['submitted_at'] ?? json['created_at']),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      verificationResult: json['verification_result'],
      establishmentName: json['establishment_name'],
      filedOnBehalf: json['filed_on_behalf'] == true,
      filedByEstablishmentName: json['filed_by_establishment_name'],
      beneficiaryAcknowledgedAt: json['beneficiary_acknowledged_at'] != null
          ? DateTime.parse(json['beneficiary_acknowledged_at'])
          : null,
    );
  }

  String get displayType => disputeType.replaceAll('_', ' ').toUpperCase();
  String get reference => referenceNo ?? id.substring(0, 8).toUpperCase();
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

class CallbackRequestRecord {
  final String id;
  final String reason;
  final String status;
  final String? staffNote;
  final DateTime createdAt;
  final DateTime? handledAt;
  final String reference;
  final String? establishmentName;

  CallbackRequestRecord({
    required this.id,
    required this.reason,
    required this.status,
    this.staffNote,
    required this.createdAt,
    this.handledAt,
    required this.reference,
    this.establishmentName,
  });

  factory CallbackRequestRecord.fromJson(Map<String, dynamic> json) {
    return CallbackRequestRecord(
      id: json['id'],
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'open',
      staffNote: json['staff_note'],
      createdAt: DateTime.parse(json['created_at']),
      handledAt: json['handled_at'] != null
          ? DateTime.parse(json['handled_at'])
          : null,
      reference: json['reference'] ?? '',
      establishmentName: json['establishment_name'],
    );
  }

  bool get isHandled => status == 'handled';
}

class CallbackRequestListResult {
  final bool success;
  final List<CallbackRequestRecord> requests;
  final String? errorMessage;

  CallbackRequestListResult({
    required this.success,
    this.requests = const [],
    this.errorMessage,
  });
}
