// settings_screen.dart

import 'package:flutter/material.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        // ... (rest of your AppBar code is unchanged)
        backgroundColor: kDarkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildUserProfile(),
              const SizedBox(height: 24),
              _buildSectionTitle('General'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Account',
                  // 👇 2. UPDATE THE onTap ACTION HERE
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.lock_outline,
                  title: 'Privacy & Security',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacySecurityScreen(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
              
              // ... (rest of your code is unchanged)
              _buildSectionTitle('Help & Support'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _buildMenuItem(
                    icon: Icons.warning_amber_outlined,
                    title: 'Report a Problem',
                    onTap: () {}),
                _buildDivider(),
                _buildMenuItem(
                    icon: Icons.mail_outline,
                    title: 'Contact Support',
                    onTap: () {}),
                _buildDivider(),
                _buildMenuItem(
                    icon: Icons.chat_bubble_outline,
                    title: 'Give Feedback',
                    onTap: () {}),
                _buildDivider(),
                _buildMenuItem(
                    icon: Icons.info_outline, title: 'App Info', onTap: () {}),
              ]),
              const SizedBox(height: 24),
              _buildDeleteAccountButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // All your helper methods (_buildUserProfile, _buildMenuItem, etc.)
  // remain exactly the same. I've omitted them here for brevity.
  // ...
  Widget _buildUserProfile() {
    // ... same as before
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.grey[800]!, Colors.grey[700]!],
            ),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white70,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'John',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'vextor@gmail.com',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    // ... same as before
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    // ... same as before
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    // ... same as before
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    // ... same as before
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: Colors.white10,
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    // ... same as before
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}