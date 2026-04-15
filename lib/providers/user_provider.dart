import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  // ─── State ────────────────────────────────────────────────────────────────
  String name = '';
  String username = '';
  String email = '';
  String phone = '';
  String photoUrl = '';
  String role = '';
  bool isLoading = true;
  String? error;

  // ─── Convenience getters ──────────────────────────────────────────────────
  String get firstName => name.split(' ').first;
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : 'P';
  bool get hasPhoto => photoUrl.isNotEmpty;

  // ─── Load user from Firestore ─────────────────────────────────────────────
  Future<void> loadUser() async {
    // ✅ Do NOT call notifyListeners() here at the start —
    //    it can trigger "setState during build" if called from AuthGate.
    //    isLoading is already true by default so no notify needed.
    isLoading = true;
    error = null;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        name = data['name'] ?? '';
        username = data['username'] ?? '';
        email = data['email'] ?? '';
        phone = data['phone'] ?? '';
        photoUrl = data['photoUrl'] ?? '';
        role = data['role'] ?? 'patient';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners(); // ✅ Safe — Firestore is async, build is long done by now
    }
  }

  // ─── Update profile ───────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String newName,
    required String newPhone,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': newName,
        'phone': newPhone,
      });

      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);

      name = newName;
      phone = newPhone;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  // ─── Clear on sign-out ────────────────────────────────────────────────────
  void clear() {
    name = username = email = phone = photoUrl = role = '';
    isLoading = true;
    error = null;
    // ✅ No notifyListeners() here either — clear() is called from
    //    addPostFrameCallback in AuthGate so it's already safe,
    //    but omitting it avoids any risk of a duplicate build.
  }
}
