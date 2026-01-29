import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<Map<String, dynamic>> _industries = [
    {
      'name': 'Agriculture',
      'desc': 'Smart farming & soil monitoring',
      'icon': Icons.agriculture_rounded,
      'color': Colors.green
    },
    {
      'name': 'Chemical',
      'desc': 'Hazardous gas & levels tracking',
      'icon': Icons.science_rounded,
      'color': Colors.purple
    },
    {
      'name': 'Cement',
      'desc': 'Dust & particulate matter control',
      'icon': Icons.business_rounded,
      'color': Colors.blueGrey
    },
    {
      'name': 'Other',
      'desc': 'General industrial monitoring',
      'icon': Icons.domain_rounded,
      'color': Colors.blue
    },
  ];

  String? _selectedIndustry;

  Future<void> _completeOnboarding() async {
    if (_selectedIndustry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an industry type'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_industry', _selectedIndustry!);
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 48,
                      color: Color(0xFF00B0FF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Select Your Industry",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tailor your dashboard to track the metrics that matter most to your operations.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- LIST ---
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _industries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = _industries[index];
                  final isSelected = _selectedIndustry == item['name'];
                  return _buildIndustryCard(item, isSelected);
                },
              ),
            ),

            // --- FOOTER BUTTON ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _selectedIndustry != null ? _completeOnboarding : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B0FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _selectedIndustry != null ? 4 : 0,
                    shadowColor: const Color(0xFF00B0FF).withOpacity(0.4),
                  ),
                  child: const Text(
                    "CONTINUE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryCard(Map<String, dynamic> item, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? item['color'].withOpacity(0.08) : Colors.white,
        border: Border.all(
          color: isSelected ? item['color'] : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: item['color'].withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndustry = item['name']),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? item['color'] : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'],
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black87
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['desc'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.grey.shade800
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkmark
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: item['color'], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
