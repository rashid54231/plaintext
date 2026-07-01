import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://hqqgocbeipdtpaulawpy.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxcWdvY2JlaXBkdHBhdWxhd3B5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMTkwNTgsImV4cCI6MjA5NTY5NTA1OH0.pXL9lSh-ujoD0m8MOhAwozrQsXM9ZhxrsFJuhgwQJJ8';

  static SupabaseClient get client => Supabase.instance.client;
}
