import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_manager.dart';

// --- OPTIMIZATION: Use the Generic Sensor Screen ---
import 'sensor_detail_screen.dart';

// Import Alert Settings
import 'alert_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? sessionCookie;

  const DashboardScreen({super.key, this.sessionCookie});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- SESSION & NETWORK ---
  final SessionManager _session = SessionManager();
  final http.Client _client = http.Client();

  // --- STATE VARIABLES ---
  String selectedDeviceId = "";
  List<dynamic> _devices = [];

  // Field Information State
  String farmerName = "--";
  String lastOnline = "--";
  String deviceStatus = "Offline";
  String deviceLocation = "--";

  bool isDeviceOffline = false;

  Map<String, dynamic>? sensorData;
  Map<String, List<double>> historyData = {};

  bool isLoading = true;
  Timer? _timer;

  // Page Controller for sliding functionality
  late PageController _pageController;
  int _currentPageIndex = 0;

  // Mock data for fallback
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
    _pageController = PageController(initialPage: 0);
    _initializeData();

    // Periodic refresh every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (selectedDeviceId.isNotEmpty) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    _pageController.dispose();
    super.dispose();
  }

  // --- CONFIGURATION FACTORY (Optimized Logic) ---
  // Returns configuration object based on sensor name
  SensorConfig _getSensorConfig(String name) {
    if (name.contains("Temperature")) {
      return SensorConfig(
        title: "Temperature",
        jsonKey: "temp", // API key for history
        unit: "°C",
        color: Colors.orange,
        icon: Icons.thermostat,
        insightLogic: (min, max, avg) =>
            avg > 35 ? "Heat alert. High average temp." : "Conditions normal.",
      );
    }
    if (name.contains("Humidity")) {
      return SensorConfig(
        title: "Humidity",
        jsonKey: "humidity",
        unit: "%",
        color: Colors.blue,
        icon: Icons.water_drop,
        insightLogic: (min, max, avg) =>
            avg > 80 ? "High humidity detected." : "Humidity is comfortable.",
      );
    }
    if (name.contains("Rainfall")) {
      return SensorConfig(
        title: "Rainfall",
        jsonKey: "rainfall",
        unit: "mm",
        color: Colors.indigo,
        icon: Icons.cloudy_snowing,
        insightLogic: (min, max, avg) =>
            max > 10 ? "Heavy rain recorded." : "No significant rainfall.",
      );
    }
    if (name.contains("Light")) {
      return SensorConfig(
        title: "Light Intensity",
        jsonKey: "light_intensity",
        unit: "lux",
        color: Colors.amber,
        icon: Icons.wb_sunny,
        insightLogic: (min, max, avg) =>
            avg > 50000 ? "Intense sunlight." : "Moderate light levels.",
      );
    }
    if (name.contains("Pressure")) {
      return SensorConfig(
        title: "Pressure",
        jsonKey: "pressure",
        unit: "hPa",
        color: Colors.deepPurple,
        icon: Icons.speed,
        insightLogic: (min, max, avg) =>
            avg < 1000 ? "Low pressure system." : "Stable atmosphere.",
      );
    }
    if (name.contains("Wind")) {
      return SensorConfig(
        title: "Wind Speed",
        jsonKey: "wind_speed",
        unit: "km/h",
        color: Colors.teal,
        icon: Icons.air,
        insightLogic: (min, max, avg) =>
            max > 30 ? "High wind alert." : "Calm winds.",
      );
    }
    if (name.contains("PM 2.5")) {
      return SensorConfig(
        title: "PM 2.5",
        jsonKey: "pm25",
        unit: "µg/m³",
        color: Colors.blueGrey,
        icon: Icons.grain,
        insightLogic: (min, max, avg) =>
            avg > 35 ? "Unhealthy air quality." : "Air quality is good.",
      );
    }
    if (name.contains("CO2")) {
      return SensorConfig(
        title: "CO2",
        jsonKey: "co2",
        unit: "ppm",
        color: Colors.green,
        icon: Icons.cloud,
        insightLogic: (min, max, avg) =>
            avg > 1000 ? "Poor ventilation." : "Fresh air.",
      );
    }
    if (name.contains("TVOC")) {
      return SensorConfig(
        title: "TVOC",
        jsonKey: "tvoc",
        unit: "ppb",
        color: Colors.brown,
        icon: Icons.science,
        insightLogic: (min, max, avg) =>
            avg > 200 ? "High volatile compounds." : "Safe TVOC levels.",
      );
    }
    if (name.contains("AQI")) {
      return SensorConfig(
        title: "AQI",
        jsonKey: "aqi",
        unit: "",
        color: Colors.cyan,
        icon: Icons.filter_drama,
        insightLogic: (min, max, avg) =>
            avg > 100 ? "Poor air quality." : "Good air quality.",
      );
    }

    // Default Fallback
    return SensorConfig(
      title: name,
      jsonKey: name.toLowerCase(),
      unit: "",
      color: Colors.grey,
      icon: Icons.device_unknown,
    );
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
        if (data is List)
          deviceList = data;
        else if (data is Map)
          deviceList = data['data'] ?? data['devices'] ?? [];

        if (deviceList.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          String? savedId = prefs.getString('selected_device_id');
          var deviceToSelect = deviceList[0];

          if (savedId != null) {
            try {
              deviceToSelect =
                  deviceList.firstWhere((d) => d['d_id'].toString() == savedId);
            } catch (_) {}
          }

          setState(() {
            _devices = deviceList;
            selectedDeviceId = deviceToSelect['d_id'].toString();
            deviceLocation = deviceToSelect['address']?.toString() ?? "Field A";
            farmerName = deviceToSelect["farm_name"]?.toString() ?? "Farmer";
          });

          await prefs.setString('selected_device_id', selectedDeviceId);
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
              } catch (_) {}
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
              "pm25": double.tryParse(reading['pm25'].toString()) ?? 0.0,
              "tvoc": double.tryParse(reading['tvoc'].toString()) ?? 0.0,
              "aqi": double.tryParse(reading['aqi'].toString()) ?? 0.0,
            };
            isLoading = false;
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
          Map<String, List<double>> newHistory = {};
          // Parse all keys
          for (var key in [
            'temp',
            'humidity',
            'rainfall',
            'light_intensity',
            'wind_speed',
            'pressure',
            'pm25',
            'tvoc',
            'aqi'
          ]) {
            newHistory[key] = readings
                .map<double>((r) => double.tryParse(r[key].toString()) ?? 0.0)
                .toList()
                .reversed
                .toList();
          }

          setState(() {
            historyData = {
              "air_temp": newHistory['temp']!,
              "humidity": newHistory['humidity']!,
              "rainfall": newHistory['rainfall']!,
              "light_intensity": newHistory['light_intensity']!,
              "wind": newHistory['wind_speed']!,
              "pressure": newHistory['pressure']!,
              "pm25": newHistory['pm25']!,
              "tvoc": newHistory['tvoc']!,
              "aqi": newHistory['aqi']!,
            };
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
    await _session.clearSession();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _switchDevice(String deviceId, String location, String name) async {
    if (selectedDeviceId == deviceId) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_device_id', deviceId);

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

  void _onCategoryTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _loadMockData() {
    if (mounted) {
      setState(() {
        isLoading = false;
        farmerName = "Aditya Farm";
        deviceStatus = "Online";
        lastOnline = "Today, 10:30 AM";

        sensorData = {
          "air_temp": 25.5,
          "humidity": 60.0,
          "rainfall": 0.0,
          "light_intensity": 1200.0,
          "wind": 12.0,
          "pressure": 1013.0,
          "pm25": 12.0,
          "tvoc": 100.0,
          "aqi": 45.0,
        };
      });
    }
  }

  // --- UI HELPERS ---
  List<Map<String, dynamic>> _getDisplayData(bool isWeather) {
    if (sensorData == null) return [];
    String v(String k, String u) => "${sensorData![k]?.toString() ?? '--'} $u";
    List<double> h(String k) => historyData[k] ?? [];

    if (isWeather) {
      return [
        {'n': 'Temperature', 'v': v('air_temp', '°C'), 'h': h('air_temp')},
        {'n': 'Humidity', 'v': v('humidity', '%'), 'h': h('humidity')},
        {'n': 'Rainfall', 'v': v('rainfall', 'mm'), 'h': h('rainfall')},
        {
          'n': 'Light Intensity',
          'v': v('light_intensity', 'lux'),
          'h': h('light_intensity')
        },
        {'n': 'Pressure', 'v': v('pressure', 'hPa'), 'h': h('pressure')},
        {'n': 'Wind Speed', 'v': v('wind', 'km/h'), 'h': h('wind')},
      ];
    } else {
      return [
        {'n': 'AQI', 'v': v('aqi', ''), 'h': h('aqi')},
        {'n': 'PM 2.5', 'v': v('pm25', 'µg/m³'), 'h': h('pm25')},
        {'n': 'TVOC', 'v': v('tvoc', 'ppb'), 'h': h('tvoc')},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeaderStatus(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildCategoryToggle(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                children: [
                  _buildPageContent("Weather Readings", _getDisplayData(true)),
                  _buildPageContent(
                      "Air Quality Readings", _getDisplayData(false)),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildPageContent(String title, List<Map<String, dynamic>> data) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            (isLoading && sensorData == null)
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ))
                : data.isEmpty
                    ? _buildNoDataState()
                    : _buildSensorGrid(data),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
              isSelected: _currentPageIndex == 0,
              onTap: () => _onCategoryTapped(0),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: "Air Quality",
              isSelected: _currentPageIndex == 1,
              onTap: () => _onCategoryTapped(1),
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

  Widget _buildSensorGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final config = _getSensorConfig(item['n']);
        return _buildSensorCard(item, config);
      },
    );
  }

  Widget _buildSensorCard(Map<String, dynamic> item, SensorConfig config) {
    // Determine status color: alert > base
    // You can refine this logic to check item['v'] against thresholds if you wish.
    Color baseColor = config.color;

    return GestureDetector(
      onTap: () {
        if (selectedDeviceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SensorDetailScreen(
                deviceId: selectedDeviceId,
                sessionCookie: _session.cookieHeader,
                config: config,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(config.icon, color: config.color, size: 20),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20, color: Colors.grey.shade300),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item['v'],
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['n'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 30,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: SparklinePainter(
                          data: item['h'],
                          color: config.color,
                          lineWidth: 2.5,
                          fill: false,
                        ),
                      ),
                    ),
                  ],
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
              leading:
                  const Icon(Icons.notifications_active, color: Colors.grey),
              title: const Text('Alert Settings',
                  style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AlertSettingsScreen()));
              },
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
  final bool fill;

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

    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    double range = maxVal - minVal;

    if (range == 0) {
      range = 1.0;
      minVal -= 0.5;
    } else {
      minVal -= range * 0.1;
      maxVal += range * 0.1;
      range = maxVal - minVal;
    }

    double dx = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double normalizeVal = (data[i] - minVal) / range;
      double x = i * dx;
      double y = size.height - (normalizeVal * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        double prevX = (i - 1) * dx;
        double prevNormalizeVal = (data[i - 1] - minVal) / range;
        double prevY = size.height - (prevNormalizeVal * size.height);
        double cX = (prevX + x) / 2;
        path.cubicTo(cX, prevY, cX, y, x, y);
      }
    }

    if (fill) {
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

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
