import 'package:supabase_flutter/supabase_flutter.dart';
import '../main/home.dart';

class SupabaseHomeNotesProvider implements HomeNotesProvider {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<NotePreview>> recentNotes() async {
    print('🔵 recentNotes() CALLED');

    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('🔴 recentNotes(): NO USER');
      return [];
    }

    final res = await _supabase
        .from('notes')
        .select('''
          id,
          file_url,
          file_type,
          created_at,
          updated_at,
          publisher_id,
          profiles:publisher_id (
            avatar_url
          )
        ''')
        .eq('user_id', user.id)
        .filter('deleted_at', 'is', null)
        .order('updated_at', ascending: false)
        .limit(10);

    print('🟢 recentNotes(): raw result = $res');

    final list = (res as List)
        .map((e) => _mapNote(e as Map<String, dynamic>))
        .toList();

    print('🟢 recentNotes(): mapped length = ${list.length}');
    return list;
  }


  // ---------------- COMMUNITY ----------------
  @override
  Future<List<NotePreview>> communityNotes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('notes')
        .select('''
          id,
          title,
          file_url,
          file_type,
          updated_at,
          publisher_id,
          profiles:publisher_id (
            username,
            avatar_url
          )
        ''')
        .eq('is_public', true)
        .neq('publisher_id', user.id)
        .order('updated_at', ascending: false)
        .limit(6);

    return (res as List).map((n) {
      return NotePreview(
        id: n['id'],
        title: n['title'] ?? '',
        updatedAt: DateTime.parse(n['updated_at']),
        isPublic: true,
        fileUrl: n['file_url'],
        fileType: n['file_type'],
        authorAvatar: n['profiles']?['avatar_url'],
        authorName: n['profiles']?['username'] ?? 'Anonymous',
        publisherId: n['publisher_id'] as String?,
      );
    }).toList();
  }


  // ---------------- FAVORITES ----------------
  @override
  Future<List<NotePreview>> favoriteNotes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _supabase
          .from('favorites')
          .select('''
            notes(
              id,
              title,
              updated_at,
              is_public,
              file_url,
              file_type,
              publisher_id,
              profiles:publisher_id (
                username,
                avatar_url
              )
            )
          ''')
          .eq('user_id', user.id)
          .order('updated_at', referencedTable: 'notes', ascending: false)
          .limit(10);

      final list = res as List<dynamic>;

      return list
          .where((row) => row['notes'] != null)
          .map((row) => _mapNote(row['notes'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('🔴 favoriteNotes() error: $e');
      return [];
    }
  }

  // ---------------- MAPPER ----------------
  NotePreview _mapNote(Map<String, dynamic> n) {
    return NotePreview(
      id: n['id'] as String,
      title: n['title'] ?? 'Untitled',
      updatedAt: DateTime.parse(n['updated_at']).toLocal(),
      isPublic: n['is_public'] ?? false,
      fileUrl: n['file_url'] as String,
      fileType: n['file_type'] as String,
      authorName: n['profiles']?['username'] ?? 'Anonymous',
      publisherId: n['publisher_id'] as String?,
    );
  }
}