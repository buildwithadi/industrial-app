import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import './notification_services.dart'; // Corrected import path (was notification_services.dart)

const String fetchBackgroundTask = "fetchBackgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background Service: Starting Task: $task");

    try {
      final prefs = await SharedPreferences.getInstance();
      final NotificationService notificationService = NotificationService();
      await notificationService.init();

      String? sessionCookie = prefs.getString('session_cookie');
      List<String>? deviceIds = prefs.getStringList('user_device_ids');

      if (sessionCookie == null) {
        print("Background Service: No session cookie. Aborting.");
        return Future.value(true);
      }
      if (deviceIds == null || deviceIds.isEmpty) {
        print("Background Service: No devices to check. Aborting.");
        return Future.value(true);
      }

      print("Background Service: Checking ${deviceIds.length} devices.");

      for (String deviceId in deviceIds) {
        bool hasAlerts = prefs.getBool('${deviceId}_has_alerts') ?? false;

        if (!hasAlerts) {
          print(
              "Background Service: Device $deviceId has no alerts enabled. Skipping.");
          continue;
        }

        try {
          print("Background Service: Fetching data for Device $deviceId...");
          final response = await http.get(
            Uri.parse('https://gridsphere.in/station/api/live-data/$deviceId'),
            headers: {
              'Cookie': sessionCookie,
              'User-Agent': 'FlutterApp',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 30)); // Add timeout

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            List<dynamic> readings = (jsonResponse is List)
                ? jsonResponse
                : (jsonResponse['data'] ?? []);

            if (readings.isNotEmpty) {
              final data = readings[0];
              String currentTimestamp = data['timestamp']?.toString() ?? "";
              String? lastProcessed =
                  prefs.getString('last_processed_$deviceId');

              print(
                  "Background Service: Data TS: $currentTimestamp (Last: $lastProcessed)");

              // --- CRITICAL: Logic to trigger alert ---
              // If timestamps differ OR if we are debugging (force check)
              if (currentTimestamp.isNotEmpty &&
                  currentTimestamp != lastProcessed) {
                print(
                    "Background Service: New data found! Checking thresholds.");

                await _check(prefs, deviceId, 'air_temp', 'Temp', data['temp'],
                    '°C', notificationService);
                await _check(prefs, deviceId, 'humidity', 'Humidity',
                    data['humidity'], '%', notificationService);
                await _check(prefs, deviceId, 'rainfall', 'Rain',
                    data['rainfall'], 'mm', notificationService);
                await _check(prefs, deviceId, 'light_intensity', 'Light',
                    data['light_intensity'], 'lux', notificationService);
                await _check(prefs, deviceId, 'pressure', 'Pressure',
                    data['pressure'], 'hPa', notificationService);
                await _check(prefs, deviceId, 'wind', 'Wind',
                    data['wind_speed'], 'km/h', notificationService);
                await _check(prefs, deviceId, 'pm25', 'PM2.5', data['pm25'],
                    'µg/m³', notificationService);
                await _check(prefs, deviceId, 'co2', 'CO2', data['co2'], 'ppm',
                    notificationService);
                await _check(prefs, deviceId, 'tvoc', 'TVOC', data['tvoc'],
                    'ppb', notificationService);
                await _check(prefs, deviceId, 'aqi', 'AQI', data['aqi'], '',
                    notificationService);

                await prefs.setString(
                    'last_processed_$deviceId', currentTimestamp);
              } else {
                print("Background Service: Data is old. No alert needed.");
              }
            }
          } else {
            print("Background Service: API Error ${response.statusCode}");
          }
        } on SocketException catch (e) {
          print("Background Service: Network Error (SocketException): $e");
          // This confirms no internet.
          // If on emulator: Check emulator wifi.
          // If on device: Check background data permissions.
        } catch (e) {
          print("Background Service: Error checking device $deviceId: $e");
        }
      }
    } catch (e) {
      print("Background Task Fatal Error: $e");
    }

    return Future.value(true);
  });
}

Future<void> _check(
  SharedPreferences prefs,
  String deviceId,
  String key,
  String label,
  dynamic rawValue,
  String unit,
  NotificationService notificationService,
) async {
  bool enabled = prefs.getBool('${deviceId}_${key}_alert_enabled') ?? false;
  if (!enabled) return;

  double? value = double.tryParse(rawValue.toString());
  if (value == null) return;

  double? min = prefs.getDouble('${deviceId}_${key}_min');
  double? max = prefs.getDouble('${deviceId}_${key}_max');

  int notifId = (deviceId + key).hashCode;

  if (max != null && value > max) {
    print("Background Service: ALERT! $label ($value) > Max ($max)");
    await notificationService.showNotification(
      notifId,
      "High $label Alert (Unit $deviceId)",
      "$label is $value $unit, exceeding limit of $max $unit.",
    );
  } else if (min != null && value < min) {
    print("Background Service: ALERT! $label ($value) < Min ($min)");
    await notificationService.showNotification(
      notifId,
      "Low $label Alert (Unit $deviceId)",
      "$label is $value $unit, below limit of $min $unit.",
    );
  }
}
