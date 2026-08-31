import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = '';
  String userEmail = '';

  bool _statsLoading = true;
  int _notesCreatedCount = 0;
  int _starredCount = 0;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    // get from profiles table
    final profile =
        await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

    setState(() {
      userName = profile['username'] ?? 'Unknown';
      userEmail = user.email ?? '';
    });
  }

  /// Pulls real counts for the stats card:
  /// - Notes Created: owned notes, excluding ones sitting in trash
  /// - Starred Notes: rows in `favorites` for this user
  /// - Notes Saved: rows in `saved_notes` for this user (community notes
  ///   they've saved to their own collection)
  Future<void> _loadStats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _statsLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        supabase
            .from('notes')
            .select('id')
            .eq('user_id', user.id)
            .filter('deleted_at', 'is', null),
        supabase.from('favorites').select('id').eq('user_id', user.id),
        supabase.from('saved_notes').select('id').eq('user_id', user.id),
      ]);

      if (!mounted) return;
      setState(() {
        _notesCreatedCount = (results[0] as List).length;
        _starredCount = (results[1] as List).length;
        _savedCount = (results[2] as List).length;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading stats: $e')));
    }
  }

  void _editName() {
    TextEditingController nameController = TextEditingController(
      text: userName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text('Edit Name', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6366F1)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Save', style: TextStyle(color: Color(0xFF6366F1))),
              onPressed: () async {
                final newName = nameController.text;

                // update supabase
                final user = Supabase.instance.client.auth.currentUser;

                await Supabase.instance.client
                    .from('profiles')
                    .update({'username': newName})
                    .eq('id', user!.id);

                setState(() {
                  userName = newName;
                });

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body:
          userName.isEmpty
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                color: Color(0xFF6366F1),
                onRefresh: () async {
                  await Future.wait([_loadProfile(), _loadStats()]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(height: 20),

                        // Avatar
                        Center(
                          child: GestureDetector(
                            onTap: () {},
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Color(0xFF2C2C2E),
                              child: ClipOval(
                                child: Image.network(
                                  'https://api.dicebear.com/7.x/avataaars/png?seed=$userName',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Name + Edit button
                        GestureDetector(
                          onTap: _editName,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.edit, color: Colors.white, size: 20),
                            ],
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          userEmail,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),

                        SizedBox(height: 32),

                        // Stats
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child:
                              _statsLoading
                                  ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                  )
                                  : Column(
                                    children: [
                                      StatisticRow(
                                        icon: Icons.note,
                                        iconColor: Color(0xFFEF4444),
                                        text:
                                            '$_notesCreatedCount Note${_notesCreatedCount == 1 ? '' : 's'} Created',
                                      ),
                                      SizedBox(height: 16),
                                      StatisticRow(
                                        icon: Icons.bookmark,
                                        iconColor: Color(0xFF3B82F6),
                                        text:
                                            '$_savedCount Note${_savedCount == 1 ? '' : 's'} Saved',
                                      ),
                                      SizedBox(height: 16),
                                      StatisticRow(
                                        icon: Icons.star,
                                        iconColor: Color(0xFFFBBF24),
                                        text:
                                            '$_starredCount Starred Note${_starredCount == 1 ? '' : 's'}',
                                      ),
                                    ],
                                  ),
                        ),

                        SizedBox(height: 32),

                        // Logout
                        GestureDetector(
                          onTap: () async {
                            await Supabase.instance.client.auth.signOut();
                            Navigator.pushReplacementNamed(context, '/');
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

class StatisticRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  StatisticRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}