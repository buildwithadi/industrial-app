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
        title: const Text("Dashboard Layout"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allSensors.length,
              itemBuilder: (context, index) {
                final sensor = _allSensors[index];
                final isVisible = _visibility[sensor] ?? true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: Text(
                      sensor,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isVisible ? "Visible on Dashboard" : "Hidden",
                      style: TextStyle(
                        color: isVisible ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    value: isVisible,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (val) => _toggleSensor(sensor, val),
                  ),
                );
              },
            ),
    );
  }
}
