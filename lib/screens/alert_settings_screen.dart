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
    'Light Intensity', // Adjusted to match Dashboard settings keys if needed
    'Pressure',
    'Wind Speed',
    'PM 2.5',
    'CO2',
    'TVOC',
    'AQI'
  ];

  // Icons to match Dashboard Settings
  final Map<String, IconData> _sensorIcons = {
    'Temperature': Icons.thermostat,
    'Humidity': Icons.water_drop,
    'Rainfall': Icons.cloudy_snowing,
    'Light Intensity': Icons.wb_sunny,
    'Pressure': Icons.speed,
    'Wind Speed': Icons.air,
    'PM 2.5': Icons.grain,
    'CO2': Icons.cloud,
    'TVOC': Icons.science,
    'AQI': Icons.filter_drama,
  };

  // Mapping display names to the keys used in JSON/SharedPreferences
  final Map<String, String> _sensorKeys = {
    'Temperature': 'air_temp',
    'Humidity': 'humidity',
    'Rainfall': 'rainfall',
    'Light Intensity': 'light_intensity',
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
      String key = _sensorKeys[sensor]!; // Use the map to get safe key

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
        title: const Text(
          "Alert Configuration",
          style: TextStyle(
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
            icon: const Icon(Icons.check_circle,
                color: Color(0xFF00B0FF), size: 28),
            onPressed: _saveSettings,
            tooltip: "Save Settings",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Set Thresholds",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ..._sensors.map((sensor) {
                  return _buildSensorCard(sensor);
                }).toList(),
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
    );
  }

  Widget _buildSensorCard(String sensor) {
    bool isEnabled = _enabled[sensor] ?? false;
    Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        children: [
          // Header Row (Matches Dashboard Settings Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? primaryColor.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _sensorIcons[sensor] ?? Icons.sensors,
                    color: isEnabled ? primaryColor : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    sensor,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      _enabled[sensor] = val;
                    });
                  },
                ),
              ],
            ),
          ),

          // Expandable Input Section
          if (isEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildThresholdInput(
                      _minControllers[sensor]!,
                      "Min Limit",
                      Icons.arrow_downward_rounded,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildThresholdInput(
                      _maxControllers[sensor]!,
                      "Max Limit",
                      Icons.arrow_upward_rounded,
                      Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdInput(TextEditingController controller, String label,
      IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, size: 16, color: color),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.5), width: 1.5),
            ),
            hintText: "--",
            hintStyle: TextStyle(color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }
}
