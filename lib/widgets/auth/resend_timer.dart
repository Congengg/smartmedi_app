import 'dart:async';
import 'package:flutter/material.dart';

class ResendTimer extends StatefulWidget {
  final Future<void> Function() onResend;
  final int cooldownSeconds;

  const ResendTimer({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 600, // Default to 10 minutes
  });

  @override
  State<ResendTimer> createState() => _ResendTimerState();
}

class _ResendTimerState extends State<ResendTimer> {
  late int _seconds;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = widget.cooldownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = widget.cooldownSeconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _seconds--;
        if (_seconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get the email? ",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 13.5,
          ),
        ),
        _canResend
            ? GestureDetector(
                onTap: () async {
                  _startTimer();
                  await widget.onResend();
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                'Resend in ${_seconds}s',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 13.5,
                ),
              ),
      ],
    );
  }
}
