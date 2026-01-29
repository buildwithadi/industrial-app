import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSettingsScreen extends StatefulWidget {
  final String deviceId;

  const DashboardSettingsScreen({super.key, required this.deviceId});

  @override
  State<DashboardSettingsScreen> createState() =>
      _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState extends State<DashboardSettingsScreen> {
  // List of all possible sensors (Display Names)
  final List<String> _allSensors = [
    'Temperature',
    'Humidity',
    'Rainfall',
    'Light Intensity',
    'Pressure',
    'Wind Speed',
    'PM 2.5',
    'CO2',
    'TVOC',
    'AQI'
  ];

  // Icons for visual flair
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

  // Map to store current visibility state
  Map<String, bool> _visibility = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Key helper: "device_101_show_Temperature"
  String _getKey(String sensorName) =>
      '${widget.deviceId}_show_${sensorName.replaceAll(' ', '')}';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var sensor in _allSensors) {
        // Default to true (visible) if not set
        _visibility[sensor] = prefs.getBool(_getKey(sensor)) ?? true;
      }
      _isLoading = false;
    });
  }

  Future<void> _toggleSensor(String sensor, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getKey(sensor), value);
    setState(() {
      _visibility[sensor] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Dashboard Layout",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Visible Parameters",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ..._allSensors.map((sensor) {
                  final isVisible = _visibility[sensor] ?? true;
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isVisible
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _sensorIcons[sensor] ?? Icons.sensors,
                          color: isVisible
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        sensor,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isVisible ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      trailing: Switch.adaptive(
                        value: isVisible,
                        activeColor: Theme.of(context).primaryColor,
                        onChanged: (val) => _toggleSensor(sensor, val),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
