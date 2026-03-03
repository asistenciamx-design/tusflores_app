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
    final response = await client.from('products').select().order('created_at', ascending: false).limit(3);
    for (var r in response) {
       print("ID: \${r['id']}");
       print("NAME: \${r['name']}");
       print("IMAGE_URLS RAW: \${r['image_urls']}");
       print("IMAGE_URLS TYPE: \${r['image_urls'].runtimeType}");
       print("TAGS RAW: \${r['tags']}");
    }
  } catch (e) {
    print("GENERAL ERROR: \$e");
  }
}
