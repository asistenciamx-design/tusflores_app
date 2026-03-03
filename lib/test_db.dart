import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ltaaogwpjpkuwdcicfeu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k',
  );
  
  final client = Supabase.instance.client;
  
  // Login with existing user token if possible or just try anonymous insert to read the exact error.
  try {
    // Attempting a direct insert with a fake UUID to see if it's an RLS issue or schema issue.
    final data = {
      'name': 'Test',
      'price': 100.0,
      'description': 'test',
      'tags': ['Test'],
      'image_url': 'test',
      'is_active': true,
      'florist_id': '00000000-0000-0000-0000-000000000000'
    };
    final response = await client.from('products').insert(data).select().single();
    print("SUCCESS: \$response");
  } on PostgrestException catch (e) {
    print("POSTGREST ERROR: code=\${e.code}, message=\${e.message}, details=\${e.details}");
  } catch (e) {
    print("GENERAL ERROR: \$e");
  }
}
