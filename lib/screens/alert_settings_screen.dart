import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertSettingsScreen extends StatefulWidget {
  final String deviceId; // Scope settings to this ID

  const AlertSettingsScreen({super.key, required this.deviceId});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};
  final Map<String, bool> _enabled = {};

  final List<String> _sensors = [
    'Temperature',
    'Humidity',
    'Rainfall',
    'Light',
    'Pressure',
    'Wind Speed',
    'PM 2.5',
    'CO2',
    'TVOC',
    'AQI'
  ];

  // Mapping display names to the keys used in JSON/SharedPreferences
  final Map<String, String> _sensorKeys = {
    'Temperature': 'air_temp',
    'Humidity': 'humidity',
    'Rainfall': 'rainfall',
    'Light': 'light_intensity',
    'Pressure': 'pressure',
    'Wind Speed': 'wind',
    'PM 2.5': 'pm25',
    'CO2': 'co2',
    'TVOC': 'tvoc',
    'AQI': 'aqi'
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Helper to generate a unique key like "101_air_temp_max"
  String _getKey(String sensorKey, String suffix) =>
      '${widget.deviceId}_${sensorKey}_$suffix';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var sensor in _sensors) {
      String key = _sensorKeys[sensor]!;

      // Load device-specific settings
      _minControllers[sensor] = TextEditingController(
          text: prefs.getDouble(_getKey(key, 'min'))?.toString() ?? '');
      _maxControllers[sensor] = TextEditingController(
          text: prefs.getDouble(_getKey(key, 'max'))?.toString() ?? '');
      _enabled[sensor] = prefs.getBool(_getKey(key, 'alert_enabled')) ?? false;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Also save a flag indicating this device has active alerts configured
    // This helps the background service decide quickly whether to process this device
    bool anyEnabled = _enabled.values.any((e) => e == true);
    await prefs.setBool('${widget.deviceId}_has_alerts', anyEnabled);

    for (var sensor in _sensors) {
      String key = _sensorKeys[sensor]!;

      if (_minControllers[sensor]!.text.isNotEmpty) {
        await prefs.setDouble(
            _getKey(key, 'min'), double.parse(_minControllers[sensor]!.text));
      } else {
        await prefs.remove(_getKey(key, 'min'));
      }

      if (_maxControllers[sensor]!.text.isNotEmpty) {
        await prefs.setDouble(
            _getKey(key, 'max'), double.parse(_maxControllers[sensor]!.text));
      } else {
        await prefs.remove(_getKey(key, 'max'));
      }

      await prefs.setBool(_getKey(key, 'alert_enabled'), _enabled[sensor]!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert settings saved for this unit')),
      );
    }
  }

  @override
  void dispose() {
    for (var c in _minControllers.values) {
      c.dispose();
    }
    for (var c in _maxControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Alerts: Unit ${widget.deviceId}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sensors.length,
              itemBuilder: (context, index) {
                String sensor = _sensors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0, // Flat style to match new design
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sensor,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Switch(
                              value: _enabled[sensor]!,
                              onChanged: (val) {
                                setState(() {
                                  _enabled[sensor] = val;
                                });
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                        if (_enabled[sensor]!) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _minControllers[sensor],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText: "Min Threshold",
                                    labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxControllers[sensor],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText: "Max Threshold",
                                    labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
