import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ltaaogwpjpkuwdcicfeu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k',
  );
  
  final client = Supabase.instance.client;
  
  try {
    final response = await client.from('shop_settings').select().limit(1);
    for (var r in response) {
       print("ID: ${r['id']}");
       print("SHOP ID: ${r['shop_id']}");
       print("SETTINGS: ${r['settings']}");
    }
  } catch (e) {
    print("GENERAL ERROR: $e");
  }
}
