import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _NotifBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x127F77DD),
      x: 0.88, y: 0.06, radius: 0.42,
      dx: 0.05, dy: 0.04, speedX: 0.7, speedY: 0.9,
    ),
    BlobConfig(
      color: Color(0x0E00D4AA),
      x: 0.08, y: 0.50, radius: 0.36,
      dx: 0.06, dy: 0.05, speedX: 1.0, speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x0A378ADD),
      x: 0.55, y: 0.82, radius: 0.28,
      dx: 0.04, dy: 0.04, speedX: 1.2, speedY: 0.7,
    ),
  ];
}

// ─── Notification type config ─────────────────────────────────────────────────
class _NotifConfig {
  final String type;
  final IconData icon;
  final Color color;
  final String label;

  const _NotifConfig({
    required this.type,
    required this.icon,
    required this.color,
    required this.label,
  });
}

const _notifConfigs = {
  'reminder': _NotifConfig(
    type: 'reminder',
    icon: Icons.alarm_rounded,
    color: Color(0xFFEF9F27),
    label: 'Reminder',
  ),
  'confirmation': _NotifConfig(
    type: 'confirmation',
    icon: Icons.check_circle_outline_rounded,
    color: Color(0xFF00D4AA),
    label: 'Confirmed',
  ),
  'update': _NotifConfig(
    type: 'update',
    icon: Icons.update_rounded,
    color: Color(0xFF378ADD),
    label: 'Update',
  ),
  'followup': _NotifConfig(
    type: 'followup',
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFF7F77DD),
    label: 'Follow-up',
  ),
  'cancellation': _NotifConfig(
    type: 'cancellation',
    icon: Icons.cancel_outlined,
    color: Color(0xFFFF6B8A),
    label: 'Cancelled',
  ),
  'general': _NotifConfig(
    type: 'general',
    icon: Icons.notifications_outlined,
    color: Color(0xFF00D4AA),
    label: 'Notice',
  ),
};

_NotifConfig _configFor(String type) =>
    _notifConfigs[type.toLowerCase()] ?? _notifConfigs['general']!;

// ─── Notification model ───────────────────────────────────────────────────────
class _Notif {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime sentAt;
  final String? appointmentId;
  final Map<String, dynamic> extra;

  const _Notif({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.sentAt,
    this.appointmentId,
    this.extra = const {},
  });

  factory _Notif.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Notif(
      id: doc.id,
      type: (d['type'] ?? 'general').toString(),
      title: (d['title'] ?? 'Notification').toString(),
      body: (d['body'] ?? d['message'] ?? '').toString(),
      isRead: (d['isRead'] as bool?) ?? false,
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appointmentId: d['appointmentId']?.toString(),
      extra: Map<String, dynamic>.from(d['extra'] ?? {}),
    );
  }
}

// ─── Notifications Page ───────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;
  String _filter = 'All';
  bool _fcmInitialised = false;

  final _filters = ['All', 'Reminder', 'Confirmed', 'Update', 'Follow-up', 'Cancelled'];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _initFCM();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  // ── FCM setup ──────────────────────────────────────────────────────────────
  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Save FCM token to Firestore
      final token = await messaging.getToken();
      if (token != null && _uid.isNotEmpty) {
        await _saveFcmToken(token);
      }

      // Refresh token listener
      messaging.onTokenRefresh.listen((newToken) {
        if (_uid.isNotEmpty) _saveFcmToken(newToken);
      });

      // Foreground message listener → save to Firestore
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background/terminated tap handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from terminated state via notification
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);

      if (mounted) setState(() => _fcmInitialised = true);
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      // Try to find user doc by uid field
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: _uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Fallback: doc ID == Auth UID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .update({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('saveFcmToken error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Save to Firestore so it appears in the list
    if (_uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _uid,
        'type': message.data['type'] ?? 'general',
        'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'isRead': false,
        'sentAt': FieldValue.serverTimestamp(),
        'appointmentId': message.data['appointmentId'],
        'extra': message.data,
      });
    } catch (e) {
      debugPrint('handleForegroundMessage error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Mark as read and optionally navigate
    final notifId = message.data['notificationId'];
    if (notifId != null) _markRead(notifId);
  }

  // ── Mark single as read ────────────────────────────────────────────────────
  Future<void> _markRead(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  // ── Mark all as read ───────────────────────────────────────────────────────
  Future<void> _markAllRead() async {
    if (_uid.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Delete notification ────────────────────────────────────────────────────
  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
  }

  // ── Filter type string ─────────────────────────────────────────────────────
  String? get _filterType {
    switch (_filter) {
      case 'Reminder':  return 'reminder';
      case 'Confirmed': return 'confirmation';
      case 'Update':    return 'update';
      case 'Follow-up': return 'followup';
      case 'Cancelled': return 'cancellation';
      default: return null;
    }
  }

  // ── Time ago helper ────────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) => Stack(
          children: [
            CustomPaint(
              painter: BlobPainter(
                _blobCtrl.value * 2 * math.pi,
                blobs: _NotifBlobs.blobs,
              ),
              size: MediaQuery.of(context).size,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0E1A).withValues(alpha: 0.55),
                    const Color(0xFF0A0E1A).withValues(alpha: 0.97),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildFcmStatusBanner(),
                  _buildFilterChips(),
                  Expanded(child: _buildNotifList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          const Spacer(),
          const Text('Notifications',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          const Spacer(),
          // Mark all read button
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.done_all_rounded, color: Color(0xFF00D4AA), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── FCM permission banner ──────────────────────────────────────────────────
  Widget _buildFcmStatusBanner() {
    if (_fcmInitialised) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _initFCM,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF9F27).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF9F27).withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          const Icon(Icons.notifications_off_outlined, color: Color(0xFFEF9F27), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Enable push notifications',
                  style: TextStyle(color: Color(0xFFEF9F27), fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Tap to allow appointment reminders & alerts',
                  style: TextStyle(color: const Color(0xFFEF9F27).withValues(alpha: 0.65), fontSize: 11.5)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF9F27), size: 18),
        ]),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _filters[i];
            final active = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF7F77DD)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF7F77DD)
                        : Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Text(f,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.50),
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Notification list ──────────────────────────────────────────────────────
  Widget _buildNotifList() {
    if (_uid.isEmpty) return _buildEmpty('Please log in to view notifications.');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .orderBy('sentAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          debugPrint('Notifications error: ${snapshot.error}');
          return _buildEmpty('Could not load notifications.\nCheck debug console for index link.');
        }

        final all = snapshot.data?.docs.map(_Notif.fromFirestore).toList() ?? [];

        // Client-side filter by type
        final filtered = _filterType == null
            ? all
            : all.where((n) => n.type == _filterType).toList();

        if (filtered.isEmpty) {
          return _buildEmpty(
            _filter == 'All'
                ? 'No notifications yet.\nYou\'ll receive appointment reminders and updates here.'
                : 'No $_filter notifications.',
          );
        }

        // Group by date
        final grouped = <String, List<_Notif>>{};
        for (final n in filtered) {
          final key = _dateGroupKey(n.sentAt);
          grouped.putIfAbsent(key, () => []).add(n);
        }

        // Unread count
        final unreadCount = all.where((n) => !n.isRead).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            if (unreadCount > 0) _buildUnreadBanner(unreadCount),
            ...grouped.entries.expand((entry) => [
              _buildDateHeader(entry.key),
              ...entry.value.map((n) => _buildNotifTile(n)),
            ]),
          ],
        );
      },
    );
  }

  String _dateGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildUnreadBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F77DD).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7F77DD).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF7F77DD),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Text('$count unread notification${count > 1 ? 's' : ''}',
            style: const TextStyle(color: Color(0xFF7F77DD), fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: _markAllRead,
          child: Text('Mark all read',
              style: TextStyle(
                  color: const Color(0xFF7F77DD).withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4)),
    );
  }

  Widget _buildNotifTile(_Notif notif) {
    final config = _configFor(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B8A).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B8A), size: 22),
      ),
      onDismissed: (_) => _delete(notif.id),
      child: GestureDetector(
        onTap: () {
          if (!notif.isRead) _markRead(notif.id);
          _showNotifDetail(notif);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? Colors.white.withValues(alpha: 0.04)
                : config.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notif.isRead
                  ? Colors.white.withValues(alpha: 0.07)
                  : config.color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: notif.isRead ? 0.08 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon,
                  color: config.color.withValues(alpha: notif.isRead ? 0.60 : 1.0),
                  size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(config.label,
                        style: TextStyle(
                            color: config.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(_timeAgo(notif.sentAt),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 11)),
                  if (!notif.isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: config.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                Text(notif.title,
                    style: TextStyle(
                      color: notif.isRead
                          ? Colors.white.withValues(alpha: 0.75)
                          : Colors.white,
                      fontSize: 13.5,
                      fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                    )),
                if (notif.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 12.5,
                          height: 1.4)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Detail bottom sheet ────────────────────────────────────────────────────
  void _showNotifDetail(_Notif notif) {
    final config = _configFor(notif.type);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141828),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Icon + type
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(config.icon, color: config.color, size: 24),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(config.label,
                      style: TextStyle(color: config.color, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${notif.sentAt.day}/${notif.sentAt.month}/${notif.sentAt.year}  ·  '
                  '${notif.sentAt.hour.toString().padLeft(2, '0')}:${notif.sentAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                ),
              ]),
            ]),

            const SizedBox(height: 20),
            Text(notif.title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),

            if (notif.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(notif.body,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                      height: 1.6)),
            ],

            // Extra details if appointment-related
            if (notif.appointmentId != null) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 14),
              _detailRow(Icons.calendar_today_rounded, 'Appointment ID', notif.appointmentId!),
            ],

            const SizedBox(height: 24),

            // Delete button
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _delete(notif.id);
              },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF6B8A).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B8A), size: 18),
                    SizedBox(width: 8),
                    Text('Delete notification',
                        style: TextStyle(
                            color: Color(0xFFFF6B8A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.40), size: 14),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11, letterSpacing: 0.3)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_off_outlined,
                  color: Colors.white.withValues(alpha: 0.18), size: 32),
            ),
            const SizedBox(height: 18),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 14,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: List.generate(5, (i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
        ),
      )),
    );
  }
}

// ─── FCM Service (call this from main.dart) ───────────────────────────────────
// Add this to your main.dart:
//
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   // Save to Firestore here if needed
// }
//
// In main():
//   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//
// ─── Firestore structure for notifications ────────────────────────────────────
// notifications/{autoId}
//   userId:        String   ← Auth UID
//   type:          String   ← 'reminder'|'confirmation'|'update'|'followup'|'cancellation'|'general'
//   title:         String
//   body:          String
//   isRead:        bool
//   sentAt:        Timestamp
//   appointmentId: String?  ← optional link to appointments doc
//   extra:         Map      ← any extra FCM data
//
// ─── Required Firestore index ─────────────────────────────────────────────────
// notifications | userId (ASC) + sentAt (DESC)
//
// ─── Required pubspec.yaml packages ──────────────────────────────────────────
// firebase_messaging: ^15.0.0
// (already have firebase_core, cloud_firestore, firebase_auth)
//
// ─── AndroidManifest.xml additions ───────────────────────────────────────────
// Inside <application>:
//   <service android:name="com.google.firebase.messaging.FirebaseMessagingService"
//            android:exported="false">
//     <intent-filter>
//       <action android:name="com.google.firebase.MESSAGING_EVENT"/>
//     </intent-filter>
//   </service>
//
// ─── iOS Info.plist additions ─────────────────────────────────────────────────
// <key>FirebaseAppDelegateProxyEnabled</key><false/>
// Enable Push Notifications capability in Xcode → Signing & Capabilities