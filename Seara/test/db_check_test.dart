import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check Supabase posts table schema', () async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://nzxmjazsegtsmsdqnisq.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56eG1qYXpzZWd0c21zZHFuaXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNjExMzMsImV4cCI6MjA3NDYzNzEzM30.kRJQfqNMJDK4RWxxMT2tcQYrugyesedxrX-V9Nq8_mU',
    );

    final client = Supabase.instance.client;

    try {
      print('Querying posts...');
      final List<dynamic> res = await client.from('posts').select().limit(1);
      if (res.isNotEmpty) {
        print('Post keys: ${res.first.keys}');
        print('Post data: ${res.first}');
      } else {
        print('posts table is empty');
      }
    } catch (e) {
      print('Error querying posts: $e');
    }
  });
}

