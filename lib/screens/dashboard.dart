import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';
// Import detailed screens
import '../detailed_screens/temperature.dart';
import '../detailed_screens/humidity.dart';
import '../detailed_screens/rainfall.dart';
import '../detailed_screens/light_intensity.dart';
import '../detailed_screens/pressure.dart';
import '../detailed_screens/wind_speed.dart';
import '../detailed_screens/pm25.dart';
import '../detailed_screens/co2.dart';
import '../detailed_screens/tvoc.dart';

class DashboardScreen extends StatefulWidget {
  final String? sessionCookie;

  const DashboardScreen({super.key, this.sessionCookie});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- SESSION & NETWORK ---
  final SessionManager _session = SessionManager();
  final http.Client _client =
      http.Client(); // Dedicated client for this screen instance

  // --- STATE VARIABLES ---
  String selectedDeviceId = "";
  List<dynamic> _devices = [];

  // Field Information State
  String farmerName = "--";
  String lastOnline = "--";
  String deviceStatus = "Offline";
  String deviceLocation = "--";

  // Offline State
  bool isDeviceOffline = false;

  Map<String, dynamic>? sensorData;
  Map<String, List<double>> historyData = {};

  bool isLoading = true;
  Timer? _timer;

  String _selectedCategory = 'Weather';

  final List<Map<String, dynamic>> _mockAirQualityData = [
    {
      'id': 'PM-01',
      'name': 'PM 2.5',
      'value': '15 µg/m³',
      'status': 'normal',
      'icon': Icons.grain,
      'history': [12.0, 14.0, 15.0, 13.0, 15.0, 16.0],
      'isNavigable': true
    },
    {
      'id': 'CO2-02',
      'name': 'CO2',
      'value': '550 ppm',
      'status': 'warning',
      'icon': Icons.cloud,
      'history': [500.0, 520.0, 550.0, 540.0, 560.0, 550.0],
      'isNavigable': true
    },
    {
      'id': 'TVOC-03',
      'name': 'TVOC',
      'value': '120 ppb',
      'status': 'normal',
      'icon': Icons.science,
      'history': [100.0, 110.0, 120.0, 115.0, 118.0, 120.0],
      'isNavigable': true
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Periodic refresh
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (selectedDeviceId.isNotEmpty) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close(); // Cancel all pending network requests for this screen
    super.dispose();
  }

  // --- INITIALIZATION ---
  Future<void> _initializeData() async {
    await _session.loadSession();
    await _fetchDevices();

    if (selectedDeviceId.isNotEmpty) {
      await _refreshData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Connection failed or no devices. Showing Offline Data."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadMockData();
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    // Don't show full loading spinner for refresh, just update UI when data arrives
    // setState(() => isLoading = true);
    await Future.wait([
      _fetchLiveData(),
      _fetchHistoryData(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  // --- API CALLS ---
  Future<void> _fetchDevices() async {
    try {
      final response = await _session.retryRequest(() => _client.get(
            Uri.parse('${_session.baseUrl}/getDevices'),
            headers: {
              'Cookie': _session.cookieHeader,
              'User-Agent': _session.userAgent,
              'Accept': 'application/json',
            },
          ));

      if (response.statusCode == 200 && mounted) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> deviceList = [];

        if (data is List) {
          deviceList = data;
        } else if (data is Map) {
          deviceList = data['data'] ?? data['devices'] ?? [];
        }

        if (deviceList.isNotEmpty) {
          setState(() {
            _devices = deviceList;
            var device = deviceList[0];
            selectedDeviceId = device['d_id'].toString();
            deviceLocation = device['address']?.toString() ?? "Field A";
            farmerName = device["farm_name"]?.toString() ?? "Farmer";
          });
        }
      }
    } catch (e) {
      debugPrint("Exception fetching devices: $e");
    }
  }

  Future<void> _fetchLiveData() async {
    if (selectedDeviceId.isEmpty || selectedDeviceId.contains("Demo")) return;

    try {
      final response = await _session.retryRequest(() => _client.get(
            Uri.parse('${_session.baseUrl}/live-data/$selectedDeviceId'),
            headers: {
              'Cookie': _session.cookieHeader,
              'User-Agent': _session.userAgent,
              'Accept': 'application/json',
            },
          ));

      if (response.statusCode == 200 && mounted) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> readings = (jsonResponse is List)
            ? jsonResponse
            : (jsonResponse['data'] ?? []);

        if (readings.isNotEmpty) {
          final reading = readings[0];

          setState(() {
            String timeStr = reading['timestamp']?.toString() ?? "";
            lastOnline = timeStr;

            bool isOffline = false;
            if (timeStr.isNotEmpty) {
              try {
                DateTime readingTime =
                    DateTime.parse(timeStr.replaceAll(' ', 'T'));
                Duration diff = DateTime.now().difference(readingTime);
                if (diff.inMinutes > 90) isOffline = true;
              } catch (e) {
                debugPrint("Date Parse Error: $e");
              }
            }

            isDeviceOffline = isOffline;
            deviceStatus = isOffline ? "Offline" : "Online";

            sensorData = {
              "air_temp": double.tryParse(reading['temp'].toString()) ?? 0.0,
              "humidity":
                  double.tryParse(reading['humidity'].toString()) ?? 0.0,
              "rainfall":
                  double.tryParse(reading['rainfall'].toString()) ?? 0.0,
              "light_intensity":
                  double.tryParse(reading['light_intensity'].toString()) ?? 0.0,
              "wind": double.tryParse(reading['wind_speed'].toString()) ?? 0.0,
              "pressure":
                  double.tryParse(reading['pressure'].toString()) ?? 0.0,
            };
          });
        }
      }
    } catch (e) {
      debugPrint("Exception fetching live data: $e");
    }
  }

  Future<void> _fetchHistoryData() async {
    if (selectedDeviceId.isEmpty || selectedDeviceId.contains("Demo")) return;

    try {
      final response = await _session.retryRequest(() => _client.get(
            Uri.parse(
                '${_session.baseUrl}/devices/$selectedDeviceId/history?range=daily'),
            headers: {
              'Cookie': _session.cookieHeader,
              'User-Agent': _session.userAgent,
              'Accept': 'application/json',
            },
          ));

      if (response.statusCode == 200 && mounted) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> readings = (jsonResponse is List)
            ? jsonResponse
            : (jsonResponse['data'] ?? []);

        if (readings.isNotEmpty) {
          List<double> extractList(String key) {
            return readings
                .map<double>((r) => double.tryParse(r[key].toString()) ?? 0.0)
                .toList();
          }

          Map<String, List<double>> newHistory = {};
          newHistory['air_temp'] = extractList('temp');
          newHistory['humidity'] = extractList('humidity');
          newHistory['rainfall'] = extractList('rainfall');
          newHistory['light_intensity'] = extractList('light_intensity');
          newHistory['wind'] = extractList('wind_speed');
          newHistory['pressure'] = extractList('pressure');

          newHistory.forEach((key, list) {
            newHistory[key] = list.reversed.toList();
          });

          setState(() {
            historyData = newHistory;
          });
        }
      }
    } catch (e) {
      debugPrint("Exception fetching history data: $e");
    }
  }

  // --- ACTIONS ---
  Future<void> _logout() async {
    setState(() => isLoading = true);
    await _session.clearSession(); // Clears memory and SharedPreferences
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _switchDevice(String deviceId, String location, String name) {
    if (selectedDeviceId == deviceId) return;

    setState(() {
      selectedDeviceId = deviceId;
      deviceLocation = location;
      farmerName = name;
      isLoading = true;
      sensorData = null;
      isDeviceOffline = false;
      deviceStatus = "Checking...";
      lastOnline = "--";
    });

    _refreshData();
  }

  void _switchCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
  }

  void _loadMockData() {
    if (mounted) {
      setState(() {
        isLoading = false;
        farmerName = "Aditya Farm";
        deviceStatus = "Online";
        lastOnline = "Today, 10:30 AM";
      });
    }
  }

  // --- UI HELPERS ---
  List<Map<String, dynamic>> _getDisplayData() {
    if (_selectedCategory == 'Air Quality') {
      return _mockAirQualityData;
    }

    if (sensorData == null) return [];

    String val(String key, String unit) =>
        "${sensorData![key]?.toString() ?? '--'} $unit";
    double rawVal(String key) =>
        double.tryParse(sensorData![key]?.toString() ?? '0') ?? 0;
    List<double> hist(String key) => historyData[key] ?? [];

    return [
      {
        'id': 'T-101',
        'name': 'Temperature',
        'value': val('air_temp', '°C'),
        'status': rawVal('air_temp') > 40 ? 'alert' : 'normal',
        'icon': Icons.thermostat,
        'history': hist('air_temp'),
        'isNavigable': true
      },
      {
        'id': 'H-202',
        'name': 'Humidity',
        'value': val('humidity', '%'),
        'status': rawVal('humidity') < 30 ? 'warning' : 'normal',
        'icon': Icons.water_drop,
        'history': hist('humidity'),
        'isNavigable': true
      },
      {
        'id': 'R-303',
        'name': 'Rainfall',
        'value': val('rainfall', 'mm'),
        'status': 'normal',
        'icon': Icons.cloudy_snowing,
        'history': hist('rainfall'),
        'isNavigable': true
      },
      {
        'id': 'L-404',
        'name': 'Light',
        'value': val('light_intensity', 'lux'),
        'status': 'normal',
        'icon': Icons.wb_sunny,
        'history': hist('light_intensity'),
        'isNavigable': true
      },
      {
        'id': 'P-505',
        'name': 'Pressure',
        'value': val('pressure', 'hPa'),
        'status': 'normal',
        'icon': Icons.speed,
        'history': hist('pressure'),
        'isNavigable': true
      },
      {
        'id': 'W-606',
        'name': 'Wind Speed',
        'value': val('wind', 'km/h'),
        'status': rawVal('wind') > 50 ? 'warning' : 'normal',
        'icon': Icons.air,
        'history': hist('wind'),
        'isNavigable': true
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayData = _getDisplayData();

    return Scaffold(
      appBar: AppBar(
        title: _devices.isEmpty
            ? const Text('UNIT DASHBOARD')
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDeviceId.isNotEmpty ? selectedDeviceId : null,
                  dropdownColor: Colors.white,
                  icon:
                      const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  hint: const Text("Select Unit"),
                  items: _devices.map<DropdownMenuItem<String>>((device) {
                    return DropdownMenuItem<String>(
                      value: device['d_id'].toString(),
                      child: Text(
                        device['farm_name'] ?? "Unknown",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      final device = _devices
                          .firstWhere((d) => d['d_id'].toString() == newValue);
                      _switchDevice(
                          newValue,
                          device['address']?.toString() ?? "Unknown",
                          device['farm_name']?.toString() ?? "Unknown");
                    }
                  },
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderStatus(),
                const SizedBox(height: 24),
                _buildCategoryToggle(),
                const SizedBox(height: 24),
                Text(
                  "$_selectedCategory READINGS".toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                isLoading && displayData.isEmpty
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ))
                    : displayData.isEmpty
                        ? _buildNoDataState()
                        : _buildSensorGrid(displayData),
              ],
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No Data Available",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: "Weather",
              isSelected: _selectedCategory == 'Weather',
              onTap: () => _switchCategory('Weather'),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: "Air Quality",
              isSelected: _selectedCategory == 'Air Quality',
              onTap: () => _switchCategory('Air Quality'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
      {required String title,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatus() {
    Color statusColor = isDeviceOffline ? Colors.red : Colors.green;
    String statusText =
        isDeviceOffline ? "OFFLINE" : deviceStatus.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "UNIT NAME",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      farmerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LOCATION",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        deviceLocation,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "LAST UPDATE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastOnline,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(List<Map<String, dynamic>> data) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Adjusted aspect ratio for better card fit
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return _buildSensorCard(item);
      },
    );
  }

  // Helper to determine specific colors for sensor types
  Color _getSensorColor(String name) {
    if (name.contains("Temperature")) return Colors.orange;
    if (name.contains("Humidity")) return Colors.blue;
    if (name.contains("Rainfall")) return Colors.indigo;
    if (name.contains("Light")) return Colors.amber;
    if (name.contains("Pressure")) return Colors.deepPurple;
    if (name.contains("Wind")) return Colors.teal;
    if (name.contains("PM 2.5")) return Colors.blueGrey;
    if (name.contains("CO2")) return Colors.green;
    if (name.contains("TVOC")) return Colors.brown;
    return Colors.grey;
  }

  Widget _buildSensorCard(Map<String, dynamic> data) {
    // Base color for the sensor type
    Color baseColor = _getSensorColor(data['name']);
    Color statusColor = baseColor;

    // Override color if there's a warning/alert
    if (data['status'] == 'warning') {
      // Keep base color but maybe show an indicator,
      // or shift towards orange/red if strictly required.
      // For this design, let's keep the thematic color but use an indicator.
    } else if (data['status'] == 'alert') {
      statusColor = Colors.red;
    }

    List<double> history = data['history'] ?? [];
    bool isNavigable = data['isNavigable'] == true;

    return GestureDetector(
      onTap: isNavigable
          ? () {
              if (selectedDeviceId.isNotEmpty) {
                if (data['name'] == 'Temperature') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TemperatureDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'Humidity') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HumidityDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'Rainfall') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RainfallDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'Light') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LightIntensityDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'Pressure') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PressureDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'Wind Speed') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => WindSpeedDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'PM 2.5') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PM25DetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'CO2') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CO2DetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                } else if (data['name'] == 'TVOC') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TVOCDetailScreen(
                              deviceId: selectedDeviceId,
                              sessionCookie: _session.cookieHeader)));
                }
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Smooth corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // ClipRRect ensures graph stays inside rounded corners
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Colored Icon container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: baseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data['icon'], color: baseColor, size: 20),
                  ),
                  if (isNavigable)
                    Icon(Icons.chevron_right,
                        size: 20, color: Colors.grey.shade300),
                ],
              ),
              const Spacer(),
              Text(
                data['value'],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                data['name'],
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              // Foreground Graph Line (Sharp)
              SizedBox(
                height: 30,
                width: double.infinity,
                child: CustomPaint(
                  painter: SparklinePainter(
                    data: history,
                    color: baseColor,
                    lineWidth: 2.5,
                    fill: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    String initial = farmerName.isNotEmpty && farmerName != "--"
        ? farmerName[0].toUpperCase()
        : "U";
    String placeholderEmail = farmerName != "--" && farmerName.isNotEmpty
        ? "${farmerName.toLowerCase().replaceAll(' ', '')}@gridsphere.in"
        : "user@gridsphere.in";

    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              accountName: Text(farmerName,
                  style: const TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.bold)),
              accountEmail: Text(placeholderEmail,
                  style: const TextStyle(color: Colors.black54)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(initial,
                    style: const TextStyle(color: Colors.white, fontSize: 24)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.grey),
              title: const Text('Dashboard',
                  style: TextStyle(color: Colors.black87)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings',
                  style: TextStyle(color: Colors.black87)),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double lineWidth;
  final bool fill; // Added fill property

  SparklinePainter({
    required this.data,
    required this.color,
    this.lineWidth = 2.0,
    this.fill = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Calculate Y range with padding to prevent edge clipping
    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    double range = maxVal - minVal;

    if (range == 0) {
      range = 1.0;
      minVal -= 0.5;
    } else {
      // Add 10% padding to top and bottom
      minVal -= range * 0.1;
      maxVal += range * 0.1;
      range = maxVal - minVal;
    }

    double dx = size.width / (data.length - 1);

    // Smooth Curve Logic (Quadratic Bezier)
    for (int i = 0; i < data.length; i++) {
      double normalizeVal = (data[i] - minVal) / range;
      double x = i * dx;
      double y = size.height - (normalizeVal * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Use cubicTo for smoother curves, or generic lineTo
        // For simple sparklines, lineTo is cleaner, but let's smooth it slightly
        double prevX = (i - 1) * dx;
        double prevNormalizeVal = (data[i - 1] - minVal) / range;
        double prevY = size.height - (prevNormalizeVal * size.height);

        // Simple smoothing: control point is halfway
        double cX = (prevX + x) / 2;
        path.cubicTo(cX, prevY, cX, y, x, y);
      }
    }

    if (fill) {
      // Close the path for filling
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      // Use shader for gradient fill
      paint.style = PaintingStyle.fill;
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.4), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
