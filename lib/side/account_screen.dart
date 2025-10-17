// account_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';

// Color constants from your myNotes.dart example for consistency
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // Controllers to manage the text in the fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // State flags to toggle between viewing and editing
  bool _isEditingName = false;
  bool _isEditingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load user data from shared_preferences
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'John';
      _emailController.text = prefs.getString('user_email') ?? 'vextor@gmail.com';
    });
  }

  // Save user data to shared_preferences
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('user_email', _emailController.text);
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
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
          'Account Settings',
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
              _buildSectionTitle('PROFILE INFORMATION'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildEditableInfoField(
                  label: 'Name',
                  controller: _nameController,
                  isEditing: _isEditingName,
                  onEditPressed: () => setState(() => _isEditingName = !_isEditingName),
                ),
                _buildDivider(),
                _buildEditableInfoField(
                  label: 'Email Address',
                  controller: _emailController,
                  isEditing: _isEditingEmail,
                  keyboardType: TextInputType.emailAddress,
                  onEditPressed: () => setState(() => _isEditingEmail = !_isEditingEmail),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('SECURITY & PRIVACY'),
              const SizedBox(height: 12),
              _buildInfoCard([
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
              _buildSectionTitle('PREFERENCES'),
              const SizedBox(height: 12),
              _buildInfoCard([
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
                  icon: Icons.language_outlined,
                  title: 'Language',
                  trailing: const Text('English', style: TextStyle(color: Colors.white54)),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for section titles, styled like 'Folder' in your example
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

  // Reusable widget for editable fields like Name and Email
  Widget _buildEditableInfoField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditPressed,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                isEditing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: keyboardType,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        controller.text,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
              color: isEditing ? Colors.white : Colors.white54,
              size: 22,
            ),
            onPressed: () async {
              await _saveUserData();
              onEditPressed();
            },
          ),
        ],
      ),
    );
  }

  // General purpose menu item for non-editable settings
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
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
              if (trailing != null) trailing,
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
            ],
          ),
        ),
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