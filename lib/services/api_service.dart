import 'dart:convert';
import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/local/local_database.dart';

class ApiService {
  // Use --dart-define=IDETECT_API_BASE_URL=http://<YOUR_IP>:3000/api to override.
  // Do NOT use localhost on a real Android phone: it points to the phone itself.
  static const String _configuredBaseUrl =
      String.fromEnvironment('IDETECT_API_BASE_URL');
  static const String _defaultBaseUrl =
      'https://idetect-capstone.onrender.com/api';
  static String get baseUrl =>
      _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : _defaultBaseUrl;

  // SharedPreferences key for the stored token
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static String _normalizeIdNumberForApi(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  // ── Token persistence ──────────────────────────────────────────────────────

  /// Load the saved token from SharedPreferences on app startup.
  /// Call this once in main() before runApp().
  static Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = Map<String, dynamic>.from(jsonDecode(userJson));
      }
      if (_token != null) {
        debugPrint('🔑 Token restored from storage.');
      } else {
        debugPrint('🔑 No saved token found — user must log in.');
      }
    } catch (e) {
      debugPrint('⚠️ Could not load token from storage: $e');
    }
  }

  /// Save the token in memory AND persist it to SharedPreferences.
  /// Stays synchronous for backward compatibility; persistence is fire-and-forget.
  static void setToken(String token, {Map<String, dynamic>? user}) {
    _token = token;
    _persistToken(token);
    if (user != null) {
      _currentUser = user;
      _persistUser(user);
    }
  }

  /// Remove the token from memory AND from SharedPreferences.
  static void clearToken() {
    _token = null;
    _currentUser = null;
    _removeToken();
    _removeUser();
  }

  /// Returns true if a token is currently loaded (user is logged in).
  static bool get isLoggedIn => _token != null;
  static Map<String, dynamic>? get currentUser => _currentUser;
  // Exposed for StatusSyncService to attach to polling requests
  static String? get token => _token;

  // Private helpers — never throws, failures are logged only.
  static Future<void> _persistToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      debugPrint('💾 Token saved to storage.');
    } catch (e) {
      debugPrint('⚠️ Could not persist token: $e');
    }
  }

  static Future<void> _removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      debugPrint('🗑️ Token removed from storage.');
    } catch (e) {
      debugPrint('⚠️ Could not remove token from storage: $e');
    }
  }

  static Future<void> _persistUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      debugPrint('⚠️ Could not persist user: $e');
    }
  }

  static Future<void> _removeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (e) {
      debugPrint('⚠️ Could not remove user from storage: $e');
    }
  }

  // ── Core verification call ─────────────────────────────────────────────────

  /// Send the OCR-extracted ID number to the API for verification.
  /// Returns a VerificationResult with status: VALID, SUSPICIOUS, INVALID, or MANUAL_REVIEW
  static Future<VerificationResult> verifyId({
    required String idNumber,
    required String beneficiaryType, // 'senior_citizen' or 'pwd'
    double? ocrConfidence,
    String? imagePath,
    bool manuallyEntered = true,
    String? extractedName,
    String? extractedDob,
  }) async {
    try {
      if (_token == null) {
        return VerificationResult.error(
            'Not authenticated. Please log in first.');
      }

      // REQ-2.9.1 / REQ-2.9.3: Check local blocked-IDs cache first.
      // If the ID is locally known to be revoked, return INVALID immediately
      // without a network round-trip — even if the server is unreachable.
      final cachedStatus = await LocalDatabase.getCachedStatus(idNumber);
      if (cachedStatus == 'revoked') {
        return VerificationResult(
          status: VerificationStatus.invalid,
          idNumber: idNumber,
          beneficiaryType: beneficiaryType,
          message:
              'This ID has been confirmed fraudulent and is permanently blocked.',
        );
      }
      if (cachedStatus == 'suspended') {
        return VerificationResult(
          status: VerificationStatus.suspicious,
          idNumber: idNumber,
          beneficiaryType: beneficiaryType,
          message: 'ID is currently under investigation.',
        );
      }

      debugPrint('🔍 Calling API: POST /verification/scan');
      debugPrint('   ID: $idNumber');
      debugPrint('   Type: $beneficiaryType');

      final normalizedIdNumber = _normalizeIdNumberForApi(idNumber);
      if (normalizedIdNumber.isEmpty) {
        return VerificationResult.error(
            'ID number is empty after normalization.');
      }

      // Backend expects confidence in 0-100 range.
      // Our OCR pipeline often uses 0.0-1.0, so normalize before sending.
      final normalizedConfidence = ocrConfidence == null
          ? null
          : (ocrConfidence <= 1.0 ? ocrConfidence * 100.0 : ocrConfidence)
              .clamp(0.0, 100.0);

      // Encode image as base64 so the server can save it for fraud investigations.
      String? imageData;
      if (imagePath != null) {
        try {
          final bytes = await dart_io.File(imagePath).readAsBytes();
          imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        } catch (_) {
          // Non-fatal — proceed without image
        }
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/verification/scan'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'id_number': normalizedIdNumber,
              'beneficiary_type': beneficiaryType,
              'ocr_confidence_score': normalizedConfidence,
              'manually_entered': manuallyEntered,
              if (imageData != null) 'image_data': imageData,
              // Cross-validation fields: sent to the server so it can compare
              // the OCR-extracted name and DOB against the stored record.
              // If they don't match, the server downgrades result to SUSPICIOUS.
              if (extractedName != null && extractedName.isNotEmpty)
                'extracted_name': extractedName,
              if (extractedDob != null && extractedDob.isNotEmpty)
                'extracted_dob': extractedDob,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 API response: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return VerificationResult.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token rejected by server — clear it so the user is sent back to login
        clearToken();
        return VerificationResult.error(
            'Session expired. Please log in again.');
      } else {
        final data = jsonDecode(response.body);
        return VerificationResult.error(
          data['message'] ??
              data['error'] ??
              'Server error (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Network error: $e');
      // REQ-2.5.6: Check local cache for recently verified matching records
      return _tryOfflineCache(idNumber, beneficiaryType, 'Network error');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Connection refused')) {
        return _tryOfflineCache(idNumber, beneficiaryType, e.toString());
      }
      return VerificationResult.error('Verification failed: $e');
    }
  }

  /// REQ-2.5.6: Attempt to return a cached verification result when offline.
  /// Cache entries older than [_cacheTtl] are rejected — a beneficiary's status
  /// may have changed (e.g., suspended) since the last successful sync.
  static const Duration _cacheTtl = Duration(hours: 6);

  static Future<VerificationResult> _tryOfflineCache(
    String idNumber,
    String beneficiaryType,
    String reason,
  ) async {
    try {
      final db = LocalDatabase();
      final cached = await db.findCachedVerification(idNumber);
      if (cached != null) {
        final ts = cached['timestamp'] as int? ?? 0;
        final cachedDate = DateTime.fromMillisecondsSinceEpoch(ts);
        final age = DateTime.now().difference(cachedDate);

        // Reject stale cache — status may be outdated (suspended, revoked)
        if (age > _cacheTtl) {
          final hoursAgo = age.inHours;
          return VerificationResult.error(
            'Cannot reach server. Cached result is $hoursAgo hour(s) old '
            'and may be outdated. Please try when online.',
          );
        }

        final formatted =
            '${cachedDate.month}/${cachedDate.day}/${cachedDate.year} '
            '${cachedDate.hour.toString().padLeft(2, '0')}:${cachedDate.minute.toString().padLeft(2, '0')}';

        final statusStr =
            (cached['verificationStatus'] ?? 'manualReview').toString();
        VerificationStatus status;
        switch (statusStr) {
          case 'valid':
            status = VerificationStatus.valid;
            break;
          case 'suspicious':
            status = VerificationStatus.suspicious;
            break;
          case 'invalid':
            status = VerificationStatus.invalid;
            break;
          default:
            status = VerificationStatus.manualReview;
        }

        return VerificationResult(
          status: status,
          beneficiaryName: cached['fullName'],
          idNumber: cached['idNumber'],
          beneficiaryType: cached['idType'],
          message: 'Last verified: $formatted',
          isOffline: true,
          offlineSyncedAt: cachedDate,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Cache lookup failed: $e');
    }
    return VerificationResult.error(
      'Cannot reach server. No cached result found for this ID.',
    );
  }

  /// Submit a fraud flag for INVALID/SUSPICIOUS scans.
  /// Returns Map with 'flag_id' on success, or Map with 'error' on failure.
  static Future<Map<String, dynamic>> reportFraudFlag({
    required String verificationLogId,
    required String idNumberFlagged,
    required String beneficiaryType,
    String? notes,
  }) async {
    try {
      if (_token == null) {
        return {'error': 'Not authenticated. Please log in first.'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/fraud-flags'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'verification_log_id': verificationLogId,
              'id_number_flagged': idNumberFlagged,
              'beneficiary_type': beneficiaryType,
              'establishment_notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'flag_id': data['flag_id'],
          'message': data['message'] ?? 'Flag submitted successfully',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'error': data['message'] ??
            'Flag submission failed (${response.statusCode}).'
      };
    } catch (e) {
      return {'error': 'Could not submit flag: $e'};
    }
  }

  /// Gap 8: Log the cashier's deliberate action on a SUSPICIOUS or MANUAL_REVIEW
  /// result. [action] must be 'approved' | 'denied' | 'reported'.
  /// Call as fire-and-forget: `ApiService.logCashierAction(...).catchError((_) {})`.
  static Future<void> logCashierAction({
    required String verificationId,
    required String action,
  }) async {
    if (_token == null) return;
    await http
        .post(
          Uri.parse('$baseUrl/verification/$verificationId/cashier-action'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'action': action}),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<AuthResult> login({
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

      if (response.statusCode == 200) {
        final token = data['token'] as String;
        // Prefer 'user' key; fall back to building it from 'establishment'
        final Map<String, dynamic>? user;
        if (data['user'] != null) {
          user = Map<String, dynamic>.from(data['user']);
        } else if (data['establishment'] != null) {
          final est = data['establishment'] as Map<String, dynamic>;
          user = {
            'id': est['id'],
            'name': est['business_name'],
            'full_name': est['owner_name'],
            'email': est['email'],
            'role': 'Establishment Account',
          };
        } else {
          user = null;
        }
        setToken(token, user: user); // also persists to SharedPreferences
        return AuthResult.success(token: token, user: user);
      } else {
        return AuthResult.failure(data['message'] ?? 'Login failed.');
      }
    } catch (e) {
      return AuthResult.failure('Cannot reach server: $e');
    }
  }

  // ── Notifications (Beneficiary) ────────────────────────────────────────────

  /// Fetch notification history for the authenticated beneficiary.
  static Future<NotificationListResult> getNotifications(
      {int page = 1, int limit = 30}) async {
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
      } else {
        return NotificationListResult(
            success: false,
            errorMessage: data['error'] ?? 'Failed to load notifications.');
      }
    } catch (e) {
      return NotificationListResult(
          success: false, errorMessage: 'Cannot reach server: $e');
    }
  }

  /// Get unread notification count.
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

  /// Mark a single notification as read.
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

  /// Mark all notifications as read.
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

  /// Report unauthorized credential use from a notification (REQ-2.11.4).
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

  // ── Verification History (REQ-2.16.5) ─────────────────────────────────────

  /// Fetch this establishment's verification transaction history from the API.
  /// Returns a list of records plus summary counts.
  static Future<Map<String, dynamic>> getVerificationHistory({
    int page = 1,
    int limit = 20,
    String? startDate, // ISO date string: 'YYYY-MM-DD'
    String? endDate,
    String? resultFilter, // 'valid' | 'suspicious' | 'invalid'
  }) async {
    try {
      if (_token == null) return {'error': 'Not authenticated.'};

      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (resultFilter != null) 'result': resultFilter,
      };

      final uri = Uri.parse('$baseUrl/verification/history')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        clearToken();
        return {'error': 'Session expired. Please log in again.'};
      } else {
        final body = jsonDecode(response.body);
        return {'error': body['message'] ?? 'Failed to load history.'};
      }
    } catch (e) {
      return {'error': 'Cannot reach server: $e'};
    }
  }

  static Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

enum VerificationStatus { valid, suspicious, invalid, manualReview, error }

class VerificationResult {
  final VerificationStatus status;
  final String? beneficiaryName;
  final String? idNumber;
  final String? beneficiaryType;
  final String? verificationId;
  final String? message;
  final String? errorMessage;
  final Map<String, dynamic>? rawData;
  // true when served from local Hive cache — server was unreachable
  final bool isOffline;
  // timestamp of the cached record that was used (for age display in the UI)
  final DateTime? offlineSyncedAt;

  VerificationResult({
    required this.status,
    this.beneficiaryName,
    this.idNumber,
    this.beneficiaryType,
    this.verificationId,
    this.message,
    this.errorMessage,
    this.rawData,
    this.isOffline = false,
    this.offlineSyncedAt,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final statusStr =
        (json['result'] ?? json['status'] ?? '').toString().toUpperCase();

    VerificationStatus status;
    switch (statusStr) {
      case 'VALID':
        status = VerificationStatus.valid;
        break;
      case 'SUSPICIOUS':
      case 'FLAGGED':
        status = VerificationStatus.suspicious;
        break;
      case 'INVALID':
      case 'NOT_FOUND':
        status = VerificationStatus.invalid;
        break;
      case 'MANUAL_REVIEW':
      case 'PENDING':
        status = VerificationStatus.manualReview;
        break;
      case 'ERROR':
        status = VerificationStatus.error;
        break;
      default:
        status = VerificationStatus.error;
    }

    // The beneficiary details are nested inside a 'beneficiary' object
    final beneficiary = json['beneficiary'] as Map<String, dynamic>?;

    return VerificationResult(
      status: status,
      beneficiaryName: beneficiary?['full_name'],
      idNumber: json['id_number'],
      beneficiaryType: beneficiary?['beneficiary_type'],
      verificationId: json['verification_id']?.toString(),
      message: json['message'],
      rawData: json,
    );
  }

  factory VerificationResult.error(String message) {
    return VerificationResult(
      status: VerificationStatus.error,
      errorMessage: message,
    );
  }

  bool get isValid => status == VerificationStatus.valid;
  bool get isSuspicious => status == VerificationStatus.suspicious;
  bool get isInvalid => status == VerificationStatus.invalid;
  bool get isError => status == VerificationStatus.error;

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

class AuthResult {
  final bool success;
  final String? token;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  AuthResult({required this.success, this.token, this.user, this.errorMessage});

  factory AuthResult.success(
      {required String token, Map<String, dynamic>? user}) {
    return AuthResult(success: true, token: token, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(success: false, errorMessage: message);
  }
}

// ── Notification models ───────────────────────────────────────────────────────

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
  // Joined fields
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

  bool get isApproved => notificationType == 'verification_approved';
  bool get isDenied => notificationType == 'verification_denied';
  bool get isVerification => isApproved || isDenied;
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
