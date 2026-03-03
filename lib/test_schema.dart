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
    final response = await client.rpc('get_table_schema', params: {'table_name': 'products'});
    print("SCHEMA: \$response");
  } catch (e) {
    print("RPC ERROR: \$e");
    
    // Fallback if RPC doesn't exist
    try {
      final query = await client.from('products').select().limit(1);
      print("ROW DATA: \$query");
    } catch (e2) {
      print("SELECT ERROR: \$e2");
    }
  }
}
