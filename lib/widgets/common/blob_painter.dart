import 'package:flutter/material.dart';
import 'dart:math' as math;

class BlobConfig {
  final Color color;
  final double x, y, dx, dy, radius, speedX, speedY;

  const BlobConfig({
    required this.color,
    required this.x,
    required this.y,
    required this.radius,
    this.dx = 0.07,
    this.dy = 0.06,
    this.speedX = 1.0,
    this.speedY = 0.8,
  });
}

class BlobPainter extends CustomPainter {
  final double t;
  final List<BlobConfig> blobs;

  BlobPainter(this.t, {required this.blobs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final blob in blobs) {
      paint.color = blob.color;
      final c = Offset(
        size.width * (blob.x + blob.dx * math.sin(t * blob.speedX)),
        size.height * (blob.y + blob.dy * math.cos(t * blob.speedY)),
      );
      canvas.drawCircle(c, size.width * blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(BlobPainter old) => old.t != t;
}

// ─── Preset blob configs per screen ──────────────────────────────────────────
class AppBlobs {
  static const login = [
    BlobConfig(
      color: Color(0x2D00D4AA), // 0xFF00D4AA @ 0.18
      x: 0.15, y: 0.18, radius: 0.38,
      dx: 0.08, dy: 0.06, speedX: 1.0, speedY: 0.7,
    ),
    BlobConfig(
      color: Color(0x235B6EF5), // 0xFF5B6EF5 @ 0.14
      x: 0.85, y: 0.25, radius: 0.42,
      dx: 0.07, dy: 0.07, speedX: 0.9, speedY: 1.1,
    ),
    BlobConfig(
      color: Color(0x1AE040A0), // 0xFFE040A0 @ 0.10
      x: 0.50, y: 0.82, radius: 0.36,
      dx: 0.06, dy: 0.05, speedX: 1.3, speedY: 0.8,
    ),
  ];

  static const register = [
    BlobConfig(
      color: Color(0x295B6EF5),
      x: 0.85, y: 0.12, radius: 0.40,
      dx: 0.07, dy: 0.06, speedX: 1.0, speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x2600D4AA),
      x: 0.10, y: 0.50, radius: 0.38,
      dx: 0.07, dy: 0.07, speedX: 0.9, speedY: 1.1,
    ),
    BlobConfig(
      color: Color(0x17E040A0),
      x: 0.55, y: 0.88, radius: 0.34,
      dx: 0.06, dy: 0.04, speedX: 1.2, speedY: 0.9,
    ),
  ];

  static const forgotPassword = [
    BlobConfig(
      color: Color(0x2600D4AA),
      x: 0.88, y: 0.10, radius: 0.36,
      dx: 0.06, dy: 0.05, speedX: 1.0, speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x215B6EF5),
      x: 0.08, y: 0.55, radius: 0.38,
      dx: 0.06, dy: 0.06, speedX: 0.9, speedY: 1.1,
    ),
    BlobConfig(
      color: Color(0x17E040A0),
      x: 0.50, y: 0.90, radius: 0.32,
      dx: 0.05, dy: 0.04, speedX: 1.3, speedY: 0.7,
    ),
  ];
}