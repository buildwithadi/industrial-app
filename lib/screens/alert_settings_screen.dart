import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};
  final Map<String, bool> _enabled = {};

  // List of sensors to configure
  final List<String> _sensors = [
    'Temperature',
    'Humidity',
    'Rainfall',
    'Light',
    'Pressure',
    'Wind Speed',
    'PM 2.5',
    'CO2',
    'TVOC'
  ];

  // Map display name to internal key (used in prefs and API logic)
  final Map<String, String> _sensorKeys = {
    'Temperature': 'air_temp',
    'Humidity': 'humidity',
    'Rainfall': 'rainfall',
    'Light': 'light_intensity',
    'Pressure': 'pressure',
    'Wind Speed': 'wind',
    'PM 2.5': 'pm25', // Ensure this matches API key if possible
    'CO2': 'co2',
    'TVOC': 'tvoc'
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var sensor in _sensors) {
      String key = _sensorKeys[sensor]!;
      _minControllers[sensor] = TextEditingController(
          text: prefs.getDouble('${key}_min')?.toString() ?? '');
      _maxControllers[sensor] = TextEditingController(
          text: prefs.getDouble('${key}_max')?.toString() ?? '');
      _enabled[sensor] = prefs.getBool('${key}_alert_enabled') ?? false;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var sensor in _sensors) {
      String key = _sensorKeys[sensor]!;

      // Save Min
      if (_minControllers[sensor]!.text.isNotEmpty) {
        await prefs.setDouble(
            '${key}_min', double.parse(_minControllers[sensor]!.text));
      } else {
        await prefs.remove('${key}_min');
      }

      // Save Max
      if (_maxControllers[sensor]!.text.isNotEmpty) {
        await prefs.setDouble(
            '${key}_max', double.parse(_maxControllers[sensor]!.text));
      } else {
        await prefs.remove('${key}_max');
      }

      // Save Toggle
      await prefs.setBool('${key}_alert_enabled', _enabled[sensor]!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert settings saved successfully')),
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
        title: const Text("Alert Settings"),
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
                                fontSize: 18,
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
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Min Threshold",
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
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Max Threshold",
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
