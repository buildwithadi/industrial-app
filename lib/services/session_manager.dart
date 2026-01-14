import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized manager to handle tokens, cookies, and session persistence.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final String baseUrl = "https://gridsphere.in/station/api";
  final String userAgent = "FlutterApp";

  String? _csrfName;
  String? _csrfToken;
  Map<String, String> _cookieJar = {};

  /// Returns the current combined cookie string for headers.
  String get cookieHeader =>
      _cookieJar.entries.map((e) => "${e.key}=${e.value}").join("; ");

  /// Persists session to local storage.
  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookieHeader);
  }

  /// Loads session from local storage.
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('session_cookie');
    if (saved != null) _updateCookieJar(saved);
  }

  /// Clears session (Logout).
  Future<void> clearSession() async {
    _cookieJar.clear();
    _csrfToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
  }

  /// Extracts cookies from 'set-cookie' header.
  void _updateCookieJar(String? rawCookies) {
    if (rawCookies == null || rawCookies.isEmpty) return;
    final regex = RegExp(r'([a-zA-Z0-9_-]+)=([^;]+)');
    final matches = regex.allMatches(rawCookies);
    final Set<String> ignoreKeys = {
      'expires',
      'max-age',
      'path',
      'domain',
      'secure',
      'httponly',
      'samesite'
    };

    for (final match in matches) {
      String key = match.group(1)?.trim() ?? "";
      String value = match.group(2)?.trim() ?? "";
      if (key.isNotEmpty && !ignoreKeys.contains(key.toLowerCase())) {
        _cookieJar[key] = value;
      }
    }
  }

  /// Fetches CSRF token only if not already present or if forced.
  Future<Map<String, String>> ensureCsrfToken(http.Client client) async {
    if (_csrfToken != null && _csrfName != null) {
      return {'name': _csrfName!, 'token': _csrfToken!};
    }

    final response = await client.get(
      Uri.parse('$baseUrl/getCSRF'),
      headers: {'User-Agent': userAgent},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _csrfName = data['csrf_name'];
      _csrfToken = data['csrf_token'];
      _updateCookieJar(response.headers['set-cookie']);
      return {'name': _csrfName!, 'token': _csrfToken!};
    }
    throw Exception("Failed to fetch CSRF token");
  }

  /// Generic request wrapper with retry logic.
  Future<http.Response> retryRequest(
    Future<http.Response> Function() requestAction, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await requestAction();
        // Capture any session cookies rotated by the server on every request
        _updateCookieJar(response.headers['set-cookie']);
        return response;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(
            Duration(seconds: attempts)); // Exponential backoff
      }
    }
    throw Exception("Request failed after $maxRetries retries");
  }
}
