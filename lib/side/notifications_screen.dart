// notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Color constants from your design system
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Notification preferences
  bool _emailAlerts = true;
  bool _pushNotifications = true;
  bool _weeklyDigest = false;
  bool _commentNotifications = true;
  bool _shareNotifications = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  // Load notification preferences from shared_preferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailAlerts = prefs.getBool('notif_email_alerts') ?? true;
      _pushNotifications = prefs.getBool('notif_push') ?? true;
      _weeklyDigest = prefs.getBool('notif_weekly_digest') ?? false;
      _commentNotifications = prefs.getBool('notif_comments') ?? true;
      _shareNotifications = prefs.getBool('notif_shares') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
    });
  }

  // Save notification preferences to shared_preferences
  Future<void> _saveNotificationPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('NOTIFICATION METHODS'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildToggleItem(
                  icon: Icons.email_outlined,
                  title: 'Email Alerts',
                  subtitle: 'Receive important updates via email',
                  value: _emailAlerts,
                  onChanged: (value) {
                    setState(() => _emailAlerts = value);
                    _saveNotificationPreference('notif_email_alerts', value);
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive instant notifications on your device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _saveNotificationPreference('notif_push', value);
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.schedule_outlined,
                  title: 'Weekly Digest',
                  subtitle: 'Summary of activity once a week',
                  value: _weeklyDigest,
                  onChanged: (value) {
                    setState(() => _weeklyDigest = value);
                    _saveNotificationPreference('notif_weekly_digest', value);
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('NOTIFICATION TYPES'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildToggleItem(
                  icon: Icons.comment_outlined,
                  title: 'Comments',
                  subtitle: 'Get notified when someone comments',
                  value: _commentNotifications,
                  onChanged: (value) {
                    setState(() => _commentNotifications = value);
                    _saveNotificationPreference('notif_comments', value);
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.share_outlined,
                  title: 'Shares',
                  subtitle: 'Get notified when notes are shared with you',
                  value: _shareNotifications,
                  onChanged: (value) {
                    setState(() => _shareNotifications = value);
                    _saveNotificationPreference('notif_shares', value);
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('SOUND & VIBRATION'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildToggleItem(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound',
                  subtitle: 'Play sound for notifications',
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _saveNotificationPreference('notif_sound', value);
                  },
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  // Helper for the main card container
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // Toggle item widget
  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: kPrimaryColor,
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.white10,
            ),
          ),
        ],
      ),
    );
  }

  // A divider with padding consistent with the Settings page
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56), // Aligns with text after icon
      child: Container(
        height: 0.5,
        color: Colors.white10,
      ),
    );
  }
}
