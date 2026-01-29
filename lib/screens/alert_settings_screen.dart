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

  String _getKey(String sensorKey, String suffix) =>
      '${widget.deviceId}_${sensorKey}_$suffix';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var sensor in _sensors) {
      String key = _sensorKeys[sensor]!;

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
        const SnackBar(
          content: Text('Alert settings saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var c in _minControllers.values) c.dispose();
    for (var c in _maxControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Alerts: Unit ${widget.deviceId}",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.blue, size: 28),
            onPressed: _saveSettings,
            tooltip: "Save Settings",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _sensors.length,
              itemBuilder: (context, index) {
                String sensor = _sensors[index];
                bool isEnabled = _enabled[sensor] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sensor,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? Colors.black87 : Colors.grey,
                              ),
                            ),
                            Switch.adaptive(
                              value: isEnabled,
                              onChanged: (val) {
                                setState(() {
                                  _enabled[sensor] = val;
                                });
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                        if (isEnabled) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildThresholdInput(
                                  _minControllers[sensor]!,
                                  "Min Threshold",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildThresholdInput(
                                  _maxControllers[sensor]!,
                                  "Max Threshold",
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

  Widget _buildThresholdInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
    );
  }
}
