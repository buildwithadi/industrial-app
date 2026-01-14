import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Import dart:ui explicitly to avoid conflicts
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- Helper class to match your reference code style ---
class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}

class TemperatureDetailScreen extends StatefulWidget {
  final String deviceId;
  final String sessionCookie;

  const TemperatureDetailScreen({
    super.key,
    required this.deviceId,
    required this.sessionCookie,
  });

  @override
  State<TemperatureDetailScreen> createState() =>
      _TemperatureDetailScreenState();
}

class _TemperatureDetailScreenState extends State<TemperatureDetailScreen> {
  // --- STATE ---
  String _selectedRange = "24h"; // Default
  List<GraphPoint> _graphData = [];
  bool _isLoading = true;
  String _errorMessage = "";

  // Stats
  double maxTemp = 0.0;
  double minTemp = 0.0;
  double avgTemp = 0.0;
  String maxTime = "--";
  String minTime = "--";

  final String _baseUrl = "https://gridsphere.in/station/api";
  final String _userAgent = "FlutterApp";

  @override
  void initState() {
    super.initState();
    _fetchHistoryData(_selectedRange);
  }

  Future<void> _fetchHistoryData(String range) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedRange = range;
      _errorMessage = "";
      _graphData = []; // Clear previous data
    });

    try {
      // Map UI range to API expected range
      String apiRange = 'daily';
      if (range == '7d') apiRange = 'weekly';
      if (range == '30d') apiRange = 'monthly';

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/devices/${widget.deviceId}/history?range=$apiRange'),
        headers: {
          'Cookie': widget.sessionCookie,
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> rawData = [];

        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          rawData = jsonResponse['data'];
        } else if (jsonResponse is List) {
          rawData = jsonResponse;
        }

        if (rawData.isNotEmpty) {
          List<GraphPoint> points = [];
          double sum = 0;
          double localMax = -999;
          double localMin = 999;
          String localMaxTime = "--";
          String localMinTime = "--";

          for (var item in rawData) {
            // Parse Value
            double val = double.tryParse(item['temp'].toString()) ?? 0.0;
            // Parse Time
            String timeStr = item['timestamp']?.toString() ?? "";
            DateTime time = DateTime.now();
            if (timeStr.isNotEmpty) {
              try {
                time = DateTime.parse(timeStr.replaceAll(' ', 'T'));
              } catch (_) {}
            }

            points.add(GraphPoint(val, time));

            // Stats Logic
            sum += val;
            if (val > localMax) {
              localMax = val;
              localMaxTime = _formatTimeForStat(time, range);
            }
            if (val < localMin) {
              localMin = val;
              localMinTime = _formatTimeForStat(time, range);
            }
          }

          // Sort by time just in case
          points.sort((a, b) => a.time.compareTo(b.time));

          if (mounted) {
            setState(() {
              _graphData = points;
              maxTemp = localMax == -999 ? 0 : localMax;
              minTemp = localMin == 999 ? 0 : localMin;
              avgTemp = points.isEmpty ? 0 : sum / points.length;
              maxTime = localMaxTime;
              minTime = localMinTime;
              _isLoading = false;
            });
          }
        } else {
          // No data found in response
          if (mounted) {
            setState(() {
              _errorMessage = "No data available for this period";
              _isLoading = false;
            });
          }
        }
      } else {
        // Server error
        if (mounted) {
          setState(() {
            _errorMessage = "Server Error: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Connection error
      debugPrint("Error fetching history: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Connection Error";
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimeForStat(DateTime dt, String range) {
    if (range == '24h') return DateFormat('h:mm a').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  // --- AI Insights Logic ---
  String _getAIInsight() {
    if (_graphData.isEmpty) return "Gathering data to generate insights...";

    double variance = maxTemp - minTemp;
    if (variance > 15) {
      return "⚠️ High volatility detected! Temperature fluctuated significantly. Check insulation or sensors.";
    } else if (avgTemp > 35) {
      return "🔥 High average temperature detected. Ensure cooling systems are active to prevent overheating.";
    } else if (avgTemp < 5) {
      return "❄️ Low average temperature detected. Risk of frost damage is high.";
    } else if (maxTemp > 40) {
      return "☀️ Critical Peak temperature reached. Immediate cooling recommended.";
    } else {
      return "✅ Optimal Conditions. Temperature is stable within a healthy range for standard operations.";
    }
  }

  // Helper to get dynamic label for Average Temp
  String _getAverageLabel() {
    if (_selectedRange == '24h') return "Average Daily";
    if (_selectedRange == '7d') return "Average Weekly";
    return "Average Monthly";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Temperature Details"),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. AI Insight Card
            if (!_isLoading && _errorMessage.isEmpty) _buildAIInsightCard(),
            const SizedBox(height: 20),

            // 2. Time Filter Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab("Day", "24h"),
                  _buildTab("Week", "7d"),
                  _buildTab("Month", "30d"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Main Stats (Max/Min)
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    "Max Temperature",
                    "${maxTemp.toStringAsFixed(1)}°C",
                    Icons.arrow_upward,
                    Colors.red,
                    maxTime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    "Min Temperature",
                    "${minTemp.toStringAsFixed(1)}°C",
                    Icons.arrow_downward,
                    Colors.blue,
                    minTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 4. Average Stat (Full Width)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.show_chart,
                            color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getAverageLabel(), // Dynamic Label
                        style: GoogleFonts.inter(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    "${avgTemp.toStringAsFixed(1)}°C",
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. Chart Section
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      "Temperature Trend",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF166534)))
                        : _errorMessage.isNotEmpty || _graphData.isEmpty
                            ? Center(
                                child: Text(
                                  _errorMessage.isNotEmpty
                                      ? _errorMessage
                                      : "No Data Available",
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              )
                            : CustomPaint(
                                painter: _DetailedChartPainter(
                                  dataPoints: _graphData,
                                  color: const Color(0xFF166534),
                                  range: _selectedRange,
                                ),
                              ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Removed Icon as requested
              Text(
                "AI Insights",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getAIInsight(),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.blue.shade900,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, String rangeKey) {
    final isSelected = _selectedRange == rangeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _fetchHistoryData(rangeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ]
                : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black87 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(
      String label, String value, IconData icon, Color color, String subText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// --- Data Model ---
class GraphPoint {
  final double value;
  final DateTime time;
  GraphPoint(this.value, this.time);
}

// --- Custom Chart Painter ---
class _DetailedChartPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final Color color;
  final String range;

  _DetailedChartPainter(
      {required this.dataPoints, required this.color, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    // Define Padding for the Graph inside the Canvas
    const double paddingLeft = 10.0;
    const double paddingRight = 10.0;
    const double paddingTop = 20.0;
    const double paddingBottom = 20.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // 1. Calculate Min/Max for Y-Axis Scaling
    double minVal = dataPoints.map((e) => e.value).reduce(min);
    double maxVal = dataPoints.map((e) => e.value).reduce(max);

    // Safety check for flat line or empty range
    double yRange = maxVal - minVal;
    if (yRange == 0) {
      yRange = 10;
      minVal -= 5;
      maxVal += 5;
    } else {
      // Add padding to value range so lines don't touch top/bottom
      minVal -= yRange * 0.1;
      maxVal += yRange * 0.1;
      yRange = maxVal - minVal;
    }

    // 2. Draw Grid Lines & Y-Axis Labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw 4 horizontal grid lines
    for (int i = 0; i <= 3; i++) {
      double y =
          paddingTop + chartHeight - (i * chartHeight / 3); // Map to chart area
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Label
      double labelVal = minVal + (i * yRange / 3);
      textPainter.text = TextSpan(
        text: labelVal.toStringAsFixed(0),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 12));
    }

    // 3. Construct Path
    final path = Path();
    final fillPath = Path();

    double dx = 0;
    if (dataPoints.length > 1) {
      dx = chartWidth / (dataPoints.length - 1);
    } else {
      dx = chartWidth;
    }

    for (int i = 0; i < dataPoints.length; i++) {
      double normalizeVal = (dataPoints[i].value - minVal) / yRange;

      // Map X to chart width + left padding
      double x = paddingLeft + (i * dx);
      if (dataPoints.length == 1) x = size.width / 2;

      // Map Y to chart height + top padding (inverted because canvas Y grows down)
      double y = paddingTop + chartHeight - (normalizeVal * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Use cubic Bezier for smooth curves
        double prevX = paddingLeft + ((i - 1) * dx);
        double prevNormalizeVal = (dataPoints[i - 1].value - minVal) / yRange;
        double prevY =
            paddingTop + chartHeight - (prevNormalizeVal * chartHeight);

        double controlX1 = prevX + dx / 2;
        double controlY1 = prevY;
        double controlX2 = x - dx / 2;
        double controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    // Close fill path
    if (dataPoints.length > 1) {
      fillPath.lineTo(paddingLeft + chartWidth, size.height);
      fillPath.lineTo(paddingLeft, size.height);
    } else {
      fillPath.lineTo(size.width / 2, size.height);
    }
    fillPath.close();

    // 4. Draw
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // 5. Draw X-Axis Labels (Time)
    int labelCount = 5;
    int step = (dataPoints.length / labelCount).ceil();
    if (step < 1) step = 1;

    for (int i = 0; i < dataPoints.length; i += step) {
      double x = paddingLeft + (i * dx);
      if (dataPoints.length == 1) x = size.width / 2;

      DateTime t = dataPoints[i].time;
      String label = "";

      if (range == '24h') {
        label = DateFormat('HH:mm').format(t);
      } else if (range == '7d') {
        label = DateFormat('E').format(t); // Mon, Tue
      } else {
        label = DateFormat('d/M').format(t); // 1/10
      }

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
