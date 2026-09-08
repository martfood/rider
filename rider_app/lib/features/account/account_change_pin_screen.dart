import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Updates the rider PIN from Account → Security (mock).
class AccountChangePinScreen extends StatefulWidget {
  /// Creates the change PIN screen.
  const AccountChangePinScreen({super.key});

  @override
  State<AccountChangePinScreen> createState() => _AccountChangePinScreenState();
}

class _AccountChangePinScreenState extends State<AccountChangePinScreen> {
  String _pin = '';

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated (mock).')),
      );
      context.pop();
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
        title: Text('Change PIN',
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Responsive.maxContainer(
        context: context,
        maxWidth: 450,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter a new 4-digit PIN. This demo does not persist changes.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppTheme.primaryColor
                          : (isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              _Keypad(isDark: isDark, onDigit: _onDigit, onDelete: _onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad(
      {required this.isDark, required this.onDigit, required this.onDelete});

  final bool isDark;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget key(String n) {
      return InkWell(
        onTap: () => onDigit(n),
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 72,
          height: 52,
          child: Center(
            child: Text(
              n,
              style: TextStyle(
                fontSize: AppTypography.font(22),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [key('1'), key('2'), key('3')]),
        const SizedBox(height: 12),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [key('4'), key('5'), key('6')]),
        const SizedBox(height: 12),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [key('7'), key('8'), key('9')]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 52),
            key('0'),
            SizedBox(
              width: 72,
              height: 52,
              child: IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.backspace_outlined,
                    color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
