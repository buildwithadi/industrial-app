import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
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
  final Map<String, String> _cookieJar = {};

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
    if (saved != null) {
      _updateCookieJar(saved,
          saveToDisk: false); // Don't re-save what we just loaded
    }
  }

  /// Clears session (Logout).
  Future<void> clearSession() async {
    _cookieJar.clear();
    _csrfName = null;
    _csrfToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
  }

  /// Extracts cookies from 'set-cookie' header.
  /// [saveToDisk] defaults to true to handle session rotation automatically.
  void _updateCookieJar(String? rawCookies, {bool saveToDisk = true}) {
    if (rawCookies == null || rawCookies.isEmpty) return;

    // Regex handles standard "Key=Value" cookie format
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

    bool changed = false;

    for (final match in matches) {
      String key = match.group(1)?.trim() ?? "";
      String value = match.group(2)?.trim() ?? "";

      if (key.isNotEmpty && !ignoreKeys.contains(key.toLowerCase())) {
        // Only update if value is different (optimization)
        if (_cookieJar[key] != value) {
          _cookieJar[key] = value;
          changed = true;
        }
      }
    }

    // If cookies changed during this request, persist them immediately.
    // This fixes the issue where session rotation happens but isn't saved.
    if (changed && saveToDisk) {
      saveSession();
    }
  }

  /// Fetches CSRF token only if not already present or if forced.
  Future<Map<String, String>> ensureCsrfToken(http.Client client) async {
    // If we already have tokens in memory, return them to save a network call
    if (_csrfToken != null && _csrfName != null) {
      return {'name': _csrfName!, 'token': _csrfToken!};
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/getCSRF'),
        headers: {'User-Agent': userAgent},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _csrfName = data['csrf_name'];
        _csrfToken = data['csrf_token'];

        // Capture initial session cookies
        _updateCookieJar(response.headers['set-cookie']);

        return {'name': _csrfName!, 'token': _csrfToken!};
      }
    } catch (e) {
      debugPrint("CSRF Fetch Error: $e");
    }
    throw Exception("Failed to fetch CSRF token");
  }

  /// Generic request wrapper with retry logic and session rotation handling.
  Future<http.Response> retryRequest(
    Future<http.Response> Function() requestAction, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await requestAction();

        // 1. Capture any session cookies rotated by the server
        _updateCookieJar(response.headers['set-cookie']);

        // 2. Stop retrying if we are unauthorized (Session expired/Invalid)
        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint("Auth failed (401/403). Stopping retries.");
          // Optional: You could trigger a global logout here via a stream
          return response;
        }

        // 3. If server error (500+), throw to trigger retry
        if (response.statusCode >= 500) {
          throw http.ClientException("Server Error ${response.statusCode}");
        }

        return response;
      } catch (e) {
        attempts++;
        debugPrint("Request attempt $attempts failed: $e");
        if (attempts >= maxRetries) rethrow;

        // Exponential backoff: 1s, 2s, 3s...
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    throw Exception("Request failed after $maxRetries retries");
  }
}
