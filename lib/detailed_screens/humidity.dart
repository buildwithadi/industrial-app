import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

class HumidityDetailScreen extends StatefulWidget {
  final String deviceId;
  final String sessionCookie;

  const HumidityDetailScreen({
    super.key,
    required this.deviceId,
    required this.sessionCookie,
  });

  @override
  State<HumidityDetailScreen> createState() => _HumidityDetailScreenState();
}

class _HumidityDetailScreenState extends State<HumidityDetailScreen> {
  // --- STATE ---
  String _selectedRange = "24h";
  List<GraphPoint> _graphData = [];
  bool _isLoading = true;
  String _errorMessage = "";

  // Stats
  double maxVal = 0.0;
  double minVal = 0.0;
  double avgVal = 0.0;
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
      _graphData = [];
    });

    try {
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
            // CHANGED: Parse 'humidity' instead of 'temp'
            double val = double.tryParse(item['humidity'].toString()) ?? 0.0;
            String timeStr = item['timestamp']?.toString() ?? "";
            DateTime time = DateTime.now();
            if (timeStr.isNotEmpty) {
              try {
                time = DateTime.parse(timeStr.replaceAll(' ', 'T'));
              } catch (_) {}
            }

            points.add(GraphPoint(val, time));

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

          points.sort((a, b) => a.time.compareTo(b.time));

          if (mounted) {
            setState(() {
              _graphData = points;
              maxVal = localMax == -999 ? 0 : localMax;
              minVal = localMin == 999 ? 0 : localMin;
              avgVal = points.isEmpty ? 0 : sum / points.length;
              maxTime = localMaxTime;
              minTime = localMinTime;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = "No data available";
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Server Error: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
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

  // --- AI Insights Logic for Humidity ---
  String _getAIInsight() {
    if (_graphData.isEmpty) return "Gathering data to generate insights...";

    double variance = maxVal - minVal;

    if (avgVal > 85) {
      return "💧 High Humidity Alert. Conditions favor fungal growth and disease. Ensure ventilation.";
    } else if (avgVal < 30) {
      return "🌵 Low Humidity Detected. Risk of dehydration/wilting. Irrigation recommended.";
    } else if (variance > 40) {
      return "⚠️ Unstable Conditions. Large humidity fluctuations detected throughout the period.";
    } else {
      return "✅ Optimal Humidity. Levels are within a stable and healthy range.";
    }
  }

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
        title: const Text("Humidity Details"),
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
            // AI Insight
            if (!_isLoading && _errorMessage.isEmpty) _buildAIInsightCard(),
            const SizedBox(height: 20),

            // Tabs
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

            // Main Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    "Max Humidity",
                    "${maxVal.toStringAsFixed(1)}%",
                    Icons.water_drop,
                    Colors.blue.shade800,
                    maxTime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    "Min Humidity",
                    "${minVal.toStringAsFixed(1)}%",
                    Icons.water_drop_outlined,
                    Colors.lightBlue,
                    minTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Average Stat
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
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.show_chart,
                            color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getAverageLabel(),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    "${avgVal.toStringAsFixed(1)}%",
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Chart
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
                      "Humidity Trend",
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
                            child:
                                CircularProgressIndicator(color: Colors.blue))
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
                                  color: Colors.blue,
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
          Text(
            "AI Insights",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
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

class GraphPoint {
  final double value;
  final DateTime time;
  GraphPoint(this.value, this.time);
}

class _DetailedChartPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final Color color;
  final String range;

  _DetailedChartPainter(
      {required this.dataPoints, required this.color, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

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

    double minVal = dataPoints.map((e) => e.value).reduce(min);
    double maxVal = dataPoints.map((e) => e.value).reduce(max);

    double yRange = maxVal - minVal;
    if (yRange == 0) {
      yRange = 10;
      minVal -= 5;
      maxVal += 5;
    } else {
      minVal -= yRange * 0.1;
      maxVal += yRange * 0.1;
      yRange = maxVal - minVal;
    }

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      double y = paddingTop + chartHeight - (i * chartHeight / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      double labelVal = minVal + (i * yRange / 3);
      textPainter.text = TextSpan(
        text: labelVal.toStringAsFixed(0),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 12));
    }

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
      double x = paddingLeft + (i * dx);
      if (dataPoints.length == 1) x = size.width / 2;
      double y = paddingTop + chartHeight - (normalizeVal * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
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

    if (dataPoints.length > 1) {
      fillPath.lineTo(paddingLeft + chartWidth, size.height);
      fillPath.lineTo(paddingLeft, size.height);
    } else {
      fillPath.lineTo(size.width / 2, size.height);
    }
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

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
        label = DateFormat('E').format(t);
      } else {
        label = DateFormat('d/M').format(t);
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
