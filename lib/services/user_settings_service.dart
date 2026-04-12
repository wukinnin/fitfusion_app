import 'package:supabase_flutter/supabase_flutter.dart';

abstract class UserSettingsService {
  Future<bool> loadShowTutorial();
  Future<void> updateShowTutorial(bool value);
}

class SupabaseUserSettingsService implements UserSettingsService {
  SupabaseUserSettingsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<bool> loadShowTutorial() async {
    final user = _client.auth.currentUser;
    if (user == null) return true;

    final row = await _client
        .from('users')
        .select('show_tutorial')
        .eq('id', user.id)
        .maybeSingle();

    return (row?['show_tutorial'] as bool?) ?? true;
  }

  @override
  Future<void> updateShowTutorial(bool value) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('users').update({'show_tutorial': value}).eq('id', user.id);
  }
}
