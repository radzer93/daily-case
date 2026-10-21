class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const languages = String.fromEnvironment('LANGUAGES', defaultValue: 'pl');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
