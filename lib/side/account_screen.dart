import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isEditingName = false;
  bool _isEditingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _loadFromSupabase(); // 👈 load real data
  }

  // --------------------------
  // LOCAL STORAGE
  // --------------------------
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _emailController.text = prefs.getString('user_email') ?? '';
    });
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('user_email', _emailController.text);
  }

  // --------------------------
  // SUPABASE FETCH
  // --------------------------
  Future<void> _loadFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('username, email')
        .eq('id', user.id)
        .single();

    setState(() {
      _nameController.text = response['username'] ?? '';
      _emailController.text = response['email'] ?? '';
    });

    _saveLocal(); // save fetched data
  }

  // --------------------------
  // SUPABASE UPDATE
  // --------------------------
  Future<void> _updateSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('profiles').update({
      'username': _nameController.text,
      'email': _emailController.text,
    }).eq('id', user.id);

    _saveLocal();
  }

  @override
  void dispose() {
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
                  onToggle: () async {
                    if (_isEditingName) {
                      await _updateSupabase();
                    }
                    setState(() => _isEditingName = !_isEditingName);
                  },
                ),

                _buildDivider(),

                _buildEditableInfoField(
                  label: 'Email Address',
                  controller: _emailController,
                  isEditing: _isEditingEmail,
                  keyboardType: TextInputType.emailAddress,
                  onToggle: () async {
                    if (_isEditingEmail) {
                      await _updateSupabase();
                    }
                    setState(() => _isEditingEmail = !_isEditingEmail);
                  },
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
                  trailing: const Text('English',
                      style: TextStyle(color: Colors.white54)),
                  onTap: () {},
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------

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

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditableInfoField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onToggle,
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
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),

                if (isEditing)
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: keyboardType,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  )
                else
                  Text(
                    controller.text,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16),
                  ),
              ],
            ),
          ),

          IconButton(
            icon: Icon(
              isEditing
                  ? Icons.check_circle_outline
                  : Icons.edit_outlined,
              color: isEditing ? kPrimaryColor : Colors.white54,
              size: 22,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }

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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              const Icon(Icons.chevron_right,
                  color: Colors.white54, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: Colors.white10,
      ),
    );
  }
}
