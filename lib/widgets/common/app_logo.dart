import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double iconSize;
  final double containerSize;
  final double borderRadius;
  final bool showText;

  const AppLogo({
    super.key,
    this.iconSize = 36,
    this.containerSize = 72,
    this.borderRadius = 20,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.40),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          const Text(
            'SmartMedi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your AI-powered health companion',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
