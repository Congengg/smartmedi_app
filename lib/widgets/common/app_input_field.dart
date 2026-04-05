import 'package:flutter/material.dart';

class AppInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? errorText;
  final String? hintText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const AppInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffix,
    this.errorText,
    this.hintText,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 14,
          letterSpacing: 0.3,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF00D4AA), size: 20),
        suffixIcon: suffix,
        errorText: errorText,
        errorStyle: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00D4AA), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.6),
        ),
      ),
    );
  }
}
