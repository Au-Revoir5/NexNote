// privacy_security_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Color constants from your design system
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  // Privacy & Security preferences
  bool _twoFactorAuth = false;
  bool _privateProfile = false;
  bool _allowMessagesFromAnyone = true;
  bool _activityStatus = true;
  bool _dataCollection = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySecurityPreferences();
  }

  // Load privacy & security preferences from shared_preferences
  Future<void> _loadPrivacySecurityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _twoFactorAuth = prefs.getBool('privacy_2fa') ?? false;
      _privateProfile = prefs.getBool('privacy_private_profile') ?? false;
      _allowMessagesFromAnyone =
          prefs.getBool('privacy_messages_anyone') ?? true;
      _activityStatus = prefs.getBool('privacy_activity_status') ?? true;
      _dataCollection = prefs.getBool('privacy_data_collection') ?? true;
    });
  }

  // Save privacy & security preference to shared_preferences
  Future<void> _savePrivacySecurityPreference(String key, bool value) async {
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
          'Privacy & Security',
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
              _buildSectionTitle('ACCOUNT SECURITY'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildMenuItem(
                  icon: Icons.lock_outlined,
                  title: 'Change Password',
                  subtitle: 'Update your password regularly',
                  onTap: () {
                    // TODO: Implement password change dialog
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.phonelink_lock_outlined,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Add an extra layer of security',
                  value: _twoFactorAuth,
                  onChanged: (value) {
                    setState(() => _twoFactorAuth = value);
                    _savePrivacySecurityPreference('privacy_2fa', value);
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('PROFILE PRIVACY'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildToggleItem(
                  icon: Icons.visibility_off_outlined,
                  title: 'Private Profile',
                  subtitle: 'Only approved users can see your profile',
                  value: _privateProfile,
                  onChanged: (value) {
                    setState(() => _privateProfile = value);
                    _savePrivacySecurityPreference('privacy_private_profile', value);
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.mail_outline,
                  title: 'Allow Messages',
                  subtitle: 'Let anyone send you messages',
                  value: _allowMessagesFromAnyone,
                  onChanged: (value) {
                    setState(() => _allowMessagesFromAnyone = value);
                    _savePrivacySecurityPreference(
                        'privacy_messages_anyone', value);
                  },
                ),
                _buildDivider(),
                _buildToggleItem(
                  icon: Icons.access_time_outlined,
                  title: 'Activity Status',
                  subtitle: 'Let others see when you are active',
                  value: _activityStatus,
                  onChanged: (value) {
                    setState(() => _activityStatus = value);
                    _savePrivacySecurityPreference('privacy_activity_status', value);
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('DATA & PRIVACY'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildToggleItem(
                  icon: Icons.analytics_outlined,
                  title: 'Data Collection',
                  subtitle: 'Help improve the app by sharing analytics',
                  value: _dataCollection,
                  onChanged: (value) {
                    setState(() => _dataCollection = value);
                    _savePrivacySecurityPreference('privacy_data_collection', value);
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.description_outlined,
                  title: 'Download Your Data',
                  subtitle: 'Get a copy of your data',
                  onTap: () {
                    // TODO: Implement data download
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  onTap: () {
                    // TODO: Implement account deletion with confirmation
                  },
                  isDestructive: true,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('BLOCKED USERS'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildMenuItem(
                  icon: Icons.block_outlined,
                  title: 'Manage Blocked Users',
                  subtitle: 'View and unblock users',
                  onTap: () {
                    // TODO: Implement blocked users management
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

  // Menu item widget with optional destructive styling
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? Colors.red : Colors.white,
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: isDestructive ? Colors.red : Colors.white54, size: 24),
            ],
          ),
        ),
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
