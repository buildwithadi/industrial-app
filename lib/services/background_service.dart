import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:grid_sphere_industrial/services/notification_services.dart';

// Key for the task
const String fetchBackgroundTask = "fetchBackgroundTask";

@pragma('vm:entry-point') // Mandatory for background execution
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final NotificationService notificationService = NotificationService();
      await notificationService.init();

      // 1. Retrieve Config
      String? sessionCookie = prefs.getString('session_cookie');
      String? deviceId = prefs.getString('selected_device_id');

      if (sessionCookie == null || deviceId == null) {
        // Cannot check alerts if not logged in or no device selected
        return Future.value(true);
      }

      // 2. Fetch Live Data
      // Note: Assuming API structure is same as dashboard
      final response = await http.get(
        Uri.parse('https://gridsphere.in/station/api/live-data/$deviceId'),
        headers: {
          'Cookie': sessionCookie,
          'User-Agent': 'FlutterApp', // Keep consistent
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> readings = [];
        if (jsonResponse is List) {
          readings = jsonResponse;
        } else if (jsonResponse['data'] is List) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          final data = readings[0];

          // 3. Check Thresholds
          await _checkAndAlert(prefs, 'air_temp', 'Temperature', data['temp'],
              '°C', notificationService, 1);
          await _checkAndAlert(prefs, 'humidity', 'Humidity', data['humidity'],
              '%', notificationService, 2);
          await _checkAndAlert(prefs, 'rainfall', 'Rainfall', data['rainfall'],
              'mm', notificationService, 3);
          await _checkAndAlert(prefs, 'light_intensity', 'Light',
              data['light_intensity'], 'lux', notificationService, 4);
          await _checkAndAlert(prefs, 'pressure', 'Pressure', data['pressure'],
              'hPa', notificationService, 5);
          await _checkAndAlert(prefs, 'wind', 'Wind Speed', data['wind_speed'],
              'km/h', notificationService, 6);
          // Add others if needed (PM2.5, etc.)
        }
      }
    } catch (e) {
      // Fail silently in background
      print("Background Task Error: $e");
    }

    return Future.value(true);
  });
}

Future<void> _checkAndAlert(
  SharedPreferences prefs,
  String key,
  String label,
  dynamic rawValue,
  String unit,
  NotificationService notificationService,
  int notifId,
) async {
  bool enabled = prefs.getBool('${key}_alert_enabled') ?? false;
  if (!enabled) return;

  double? value = double.tryParse(rawValue.toString());
  if (value == null) return;

  double? min = prefs.getDouble('${key}_min');
  double? max = prefs.getDouble('${key}_max');

  if (max != null && value > max) {
    await notificationService.showNotification(
      notifId,
      "High $label Alert!",
      "$label is $value $unit, exceeding limit of $max $unit.",
    );
  } else if (min != null && value < min) {
    await notificationService.showNotification(
      notifId,
      "Low $label Alert!",
      "$label is $value $unit, below limit of $min $unit.",
    );
  }
}
