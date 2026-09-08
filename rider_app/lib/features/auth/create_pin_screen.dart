import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Creates a 4-digit security PIN after registration (mock).
class RiderCreatePinScreen extends StatefulWidget {
  /// Creates the PIN setup screen.
  const RiderCreatePinScreen({super.key});

  @override
  State<RiderCreatePinScreen> createState() => _RiderCreatePinScreenState();
}

class _RiderCreatePinScreenState extends State<RiderCreatePinScreen> {
  String _pin = '';

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        context.push('/auth/success');
      });
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
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
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create security PIN',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.font(AppFontSizes.headlineSmall),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 400,
            child: Padding(
              padding: Responsive.padding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Section: Instructions and PIN Dots
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'You’ll use this PIN when signing in and for sensitive actions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? AppTheme.primaryColor
                                  : (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200),
                              border: Border.all(
                                color: filled
                                    ? AppTheme.primaryColor
                                    : (isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300),
                                width: 1,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  // Spacer to push keypad to the bottom
                  const Spacer(),

                  // Bottom Section: Keypad
                  _Keypad(isDark: isDark, onDigit: _onDigit, onDelete: _onDelete),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.isDark,
    required this.onDigit,
    required this.onDelete,
  });

  final bool isDark;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const _KeyPlaceholder(),
            _KeyButton(
              label: '0',
              isDark: isDark,
              onTap: () => onDigit('0'),
            ),
            _KeyButton(
              icon: Icons.backspace_outlined,
              isDark: isDark,
              onTap: onDelete,
              isAction: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> labels) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels
          .map((l) => _KeyButton(
                label: l,
                isDark: isDark,
                onTap: () => onDigit(l),
              ))
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    required this.isDark,
    required this.onTap,
    this.isAction = false,
  });

  final String? label;
  final IconData? icon;
  final bool isDark;
  final VoidCallback onTap;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: isDark ? Colors.white : Colors.black,
                    size: 24,
                  )
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.displaySmall),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _KeyPlaceholder extends StatelessWidget {
  const _KeyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 75, height: 75);
  }
}
