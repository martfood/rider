import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/custom_button.dart';
import 'package:shared_widgets/widgets/custom_text_field.dart';

/// Rider profile details collected after OTP.
class PersonalInfoScreen extends StatefulWidget {
  /// Creates the personal info screen.
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  String? _vehicle;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Personal info'),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: AppTypography.font(AppFontSizes.headlineSmall),
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: Responsive.maxContainer(
          context: context,
          maxWidth: 450,
          child: SingleChildScrollView(
            padding: Responsive.padding(context),
            child: Column(
              children: [
                CustomTextField(
                  hintText: 'Full name',
                  controller: _name,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Phone number',
                  controller: _phone,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'City',
                  controller: _city,
                  prefixIcon: Icons.location_city_outlined,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    boxShadow: AppTheme.getShadow(context),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _vehicle,
                    decoration: InputDecoration(
                      hintText: 'Vehicle type',
                      prefixIcon: const Icon(Icons.pedal_bike,
                          color: AppTheme.primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                      DropdownMenuItem(
                          value: 'Motorcycle', child: Text('Motorcycle')),
                      DropdownMenuItem(value: 'E-bike', child: Text('E-bike')),
                    ],
                    onChanged: (v) => setState(() => _vehicle = v),
                  ),
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: 'Continue',
                  onPressed: () => context.push('/auth/pin'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
