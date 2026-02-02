import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alert_settings_screen.dart';
import 'dashboard_settings_screen.dart';

class GeneralSettingsScreen extends StatefulWidget {
  final String deviceId;

  const GeneralSettingsScreen({super.key, required this.deviceId});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  String _currentIndustry = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadIndustry();
  }

  Future<void> _loadIndustry() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentIndustry = prefs.getString('selected_industry') ?? "Other";
    });
  }

  Future<void> _updateIndustry(String newIndustry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_industry', newIndustry);
    setState(() {
      _currentIndustry = newIndustry;
    });
  }

  void _showIndustryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Industry",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildIndustryOption(
                  "Agriculture", Icons.agriculture_rounded, Colors.green),
              _buildIndustryOption(
                  "Chemical", Icons.science_rounded, Colors.purple),
              _buildIndustryOption(
                  "Cement", Icons.business_rounded, Colors.blueGrey),
              _buildIndustryOption("Other", Icons.domain_rounded, Colors.blue),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndustryOption(String name, IconData icon, Color color) {
    bool isSelected = _currentIndustry == name;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.grey[700],
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
      onTap: () {
        _updateIndustry(name);
        Navigator.pop(context);
      },
    );
  }

  IconData _getIndustryIcon(String name) {
    switch (name) {
      case 'Agriculture':
        return Icons.agriculture_rounded;
      case 'Chemical':
        return Icons.science_rounded;
      case 'Cement':
        return Icons.business_rounded;
      default:
        return Icons.domain_rounded;
    }
  }

  Color _getIndustryColor(String name) {
    switch (name) {
      case 'Agriculture':
        return Colors.green;
      case 'Chemical':
        return Colors.purple;
      case 'Cement':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Settings",
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Unit Configuration"),
          const SizedBox(height: 12),
          _buildSettingsCard(
            context,
            title: "Dashboard Layout",
            subtitle: "Customize visible sensors and order",
            icon: Icons.grid_view_rounded,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DashboardSettingsScreen(deviceId: widget.deviceId),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            context,
            title: "Alert Settings",
            subtitle: "Set thresholds for notifications",
            icon: Icons.notifications_active,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AlertSettingsScreen(deviceId: widget.deviceId),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showIndustryPicker,
        elevation: 4,
        backgroundColor: _getIndustryColor(_currentIndustry),
        icon: Icon(_getIndustryIcon(_currentIndustry), color: Colors.white),
        label: Text(
          "Current Industry: $_currentIndustry",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
