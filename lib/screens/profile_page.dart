import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartmedi_app/screens/auth/login.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _ProfileBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x1600D4AA),
      x: 0.85, y: 0.08, radius: 0.42,
      dx: 0.05, dy: 0.04, speedX: 0.7, speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x115B6EF5),
      x: 0.10, y: 0.40, radius: 0.36,
      dx: 0.05, dy: 0.05, speedX: 0.9, speedY: 1.0,
    ),
    BlobConfig(
      color: Color(0x0BE040A0),
      x: 0.55, y: 0.80, radius: 0.30,
      dx: 0.04, dy: 0.04, speedX: 1.1, speedY: 0.7,
    ),
  ];
}

// ─── Setting item model ───────────────────────────────────────────────────────
class _SettingItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });
}

// ─── Profile Page ─────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;

  // User data
  String _name = '';
  String _username = '';
  String _email = '';
  String _phone = '';
  bool _loading = true;

  // Settings toggles
  bool _notificationsEnabled = true;
  bool _emailAlertsEnabled = false;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadUser();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  // ─── Load user from Firestore ────────────────────────────────────────────────
  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _name = data['name'] ?? '';
          _username = data['username'] ?? '';
          _email = data['email'] ?? '';
          _phone = data['phone'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Sign out ────────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildSignOutDialog(ctx),
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  // ─── Delete account dialog ───────────────────────────────────────────────────
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _buildDeleteDialog(ctx),
    );
  }

  // ─── Edit profile bottom sheet ───────────────────────────────────────────────
  void _showEditProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        name: _name,
        phone: _phone,
        onSaved: (name, phone) {
          setState(() {
            _name = name;
            _phone = phone;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              CustomPaint(
                painter: BlobPainter(
                  _blobCtrl.value * 2 * math.pi,
                  blobs: _ProfileBlobs.blobs,
                ),
                size: MediaQuery.of(context).size,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0E1A).withValues(alpha: 0.50),
                      const Color(0xFF0A0E1A).withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildProfileCard()),
                    SliverToBoxAdapter(child: _buildStatsRow()),
                    SliverToBoxAdapter(child: _buildSection(
                      title: 'Account',
                      items: _accountItems,
                    )),
                    SliverToBoxAdapter(child: _buildSection(
                      title: 'Preferences',
                      items: _preferenceItems,
                    )),
                    SliverToBoxAdapter(child: _buildSection(
                      title: 'Support',
                      items: _supportItems,
                    )),
                    SliverToBoxAdapter(child: _buildDangerZone()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
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
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // Edit button
          GestureDetector(
            onTap: _showEditProfile,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF00D4AA),
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile card ─────────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1.2,
          ),
        ),
        child: _loading
            ? _buildProfileSkeleton()
            : Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4AA)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _name.isNotEmpty
                                ? _name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Patient badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0A0E1A),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@$_username',
                          style: TextStyle(
                            color: const Color(0xFF00D4AA)
                                .withValues(alpha: 0.80),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Patient pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF00D4AA)
                                  .withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.personal_injury_outlined,
                                color: Color(0xFF00D4AA),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Patient',
                                style: TextStyle(
                                  color: Color(0xFF00D4AA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmer(width: 140, height: 18),
              const SizedBox(height: 8),
              _shimmer(width: 100, height: 13),
              const SizedBox(height: 10),
              _shimmer(width: 70, height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ─── Stats row ────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _buildStatCard(
            label: 'Appointments',
            value: '12',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF378ADD),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Symptom checks',
            value: '8',
            icon: Icons.psychology_outlined,
            color: const Color(0xFF7F77DD),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Records',
            value: '5',
            icon: Icons.folder_open_rounded,
            color: const Color(0xFFD85A30),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Settings section ─────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required List<_SettingItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    _buildSettingRow(e.value),
                    if (!isLast)
                      Divider(
                        color: Colors.white.withValues(alpha: 0.06),
                        height: 1,
                        indent: 56,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(_SettingItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            item.trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  // ─── Account settings items ───────────────────────────────────────────────────
  List<_SettingItem> get _accountItems => [
        _SettingItem(
          icon: Icons.person_outline_rounded,
          label: 'Personal information',
          subtitle: _loading ? '' : _email,
          color: const Color(0xFF00D4AA),
          onTap: _showEditProfile,
        ),
        _SettingItem(
          icon: Icons.phone_outlined,
          label: 'Phone number',
          subtitle: _loading ? '' : (_phone.isEmpty ? 'Not set' : _phone),
          color: const Color(0xFF378ADD),
          onTap: _showEditProfile,
        ),
        _SettingItem(
          icon: Icons.lock_outline_rounded,
          label: 'Change password',
          color: const Color(0xFF7F77DD),
          onTap: () {
            // TODO: Navigate to ChangePasswordPage
          },
        ),
        _SettingItem(
          icon: Icons.health_and_safety_outlined,
          label: 'Medical history',
          subtitle: 'Conditions, allergies, medications',
          color: const Color(0xFFD85A30),
          onTap: () {
            // TODO: Navigate to MedicalHistoryPage
          },
        ),
      ];

  // ─── Preference items ─────────────────────────────────────────────────────────
  List<_SettingItem> get _preferenceItems => [
        _SettingItem(
          icon: Icons.notifications_outlined,
          label: 'Push notifications',
          color: const Color(0xFF00D4AA),
          onTap: () =>
              setState(() => _notificationsEnabled = !_notificationsEnabled),
          trailing: _buildToggle(_notificationsEnabled, (v) {
            setState(() => _notificationsEnabled = v);
          }),
        ),
        _SettingItem(
          icon: Icons.mail_outline_rounded,
          label: 'Email alerts',
          color: const Color(0xFF378ADD),
          onTap: () =>
              setState(() => _emailAlertsEnabled = !_emailAlertsEnabled),
          trailing: _buildToggle(_emailAlertsEnabled, (v) {
            setState(() => _emailAlertsEnabled = v);
          }),
        ),
        _SettingItem(
          icon: Icons.language_rounded,
          label: 'Language',
          subtitle: 'English',
          color: const Color(0xFF7F77DD),
          onTap: () {
            // TODO: Language picker
          },
        ),
      ];

  // ─── Support items ────────────────────────────────────────────────────────────
  List<_SettingItem> get _supportItems => [
        _SettingItem(
          icon: Icons.help_outline_rounded,
          label: 'Help & FAQ',
          color: const Color(0xFF00D4AA),
          onTap: () {
            // TODO: Navigate to HelpPage
          },
        ),
        _SettingItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy policy',
          color: const Color(0xFF378ADD),
          onTap: () {
            // TODO: Navigate to PrivacyPage
          },
        ),
        _SettingItem(
          icon: Icons.description_outlined,
          label: 'Terms of service',
          color: const Color(0xFF7F77DD),
          onTap: () {
            // TODO: Navigate to TermsPage
          },
        ),
        _SettingItem(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          color: const Color(0xFFFF6B8A),
          onTap: _signOut,
        ),
      ];

  // ─── Toggle widget ────────────────────────────────────────────────────────────
  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF00D4AA)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Danger zone ──────────────────────────────────────────────────────────────
  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: _showDeleteAccountDialog,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B8A).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF6B8A).withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B8A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete account',
                      style: TextStyle(
                        color: Color(0xFFFF6B8A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Permanently remove your data',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.50),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sign out dialog ──────────────────────────────────────────────────────────
  Widget _buildSignOutDialog(BuildContext ctx) {
    return Dialog(
      backgroundColor: const Color(0xFF141828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF6B8A),
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign out?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be returned to the login screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B8A),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF6B8A).withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Sign out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Delete account dialog ────────────────────────────────────────────────────
  Widget _buildDeleteDialog(BuildContext ctx) {
    return Dialog(
      backgroundColor: const Color(0xFF141828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFFF6B8A),
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete account?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action is permanent and cannot be undone. All your data will be removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      // TODO: Delete account from Firebase Auth + Firestore
                      // await FirebaseAuth.instance.currentUser?.delete();
                      // await FirebaseFirestore.instance
                      //     .collection('users')
                      //     .doc(uid)
                      //     .delete();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B8A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom navigation bar ────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
              _navItem(icon: Icons.search_rounded, label: 'Doctors', onTap: () {}),
              _navItem(icon: Icons.psychology_outlined, label: 'Symptom', onTap: () {}),
              _navItem(icon: Icons.folder_open_rounded, label: 'Records', onTap: () {}),
              _navItem(icon: Icons.person_rounded, label: 'Profile', active: true, onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00D4AA).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFF00D4AA)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Profile Bottom Sheet ────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String name;
  final String phone;
  final void Function(String name, String phone) onSaved;

  const _EditProfileSheet({
    required this.name,
    required this.phone,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _phoneCtrl = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': name,
          'phone': phone,
        });
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }
      widget.onSaved(name, phone);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // TODO: show error snackbar
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Edit profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          _buildField(
            controller: _nameCtrl,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),

          // Phone field
          _buildField(
            controller: _phoneCtrl,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _saving
                ? Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4AA).withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF00D4AA), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.10), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF00D4AA), width: 1.6),
        ),
      ),
    );
  }
}