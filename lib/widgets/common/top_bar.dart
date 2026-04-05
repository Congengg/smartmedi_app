import 'package:flutter/material.dart';
import 'app_logo.dart';

class TopBar extends StatelessWidget {
  final VoidCallback? onBack;

  const TopBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack ?? () => Navigator.pop(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const Spacer(),
        const AppLogo(
          containerSize: 48,
          iconSize: 24,
          borderRadius: 14,
          showText: false,
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }
}
