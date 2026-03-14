import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://ltaaogwpjpkuwdcicfeu.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k';
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  var dummyOrder = {
    'shop_id': '00000000-0000-0000-0000-000000000000',
    'folio': '#1234',
    'product_name': 'Test',
    'customer_name': 'Test',
    'customer_phone': '5555555555',
    'quantity': 1,
    'price': 100.0,
    'status': 'pending',
    'created_at': DateTime.now().toIso8601String(),
    'sale_date': DateTime.now().toIso8601String(),
    'delivery_info': 'Test',
    'is_paid': false,
    'shipping_cost': 0.0,
    'delivery_method': 'Envío a domicilio',
    'is_anonymous': false,
    'recipient_name': 'TestRecipient',
    'recipient_phone': '12345',
    'dedication_message': 'Msg',
    'delivery_address': 'Addr',
    'delivery_references': 'Ref',
    'delivery_location_type': 'House',
    'delivery_state': 'State',
    'delivery_city': 'City',
  };

  print('Searching for missing columns...');

  while (dummyOrder.isNotEmpty) {
    try {
      final response = await supabase.from('orders').insert(dummyOrder).select().single();
      print('Success! Order inserted with remaining keys: \${dummyOrder.keys}'); 
      break;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204') {
        final match = RegExp(r"Could not find the '(.*?)' column").firstMatch(e.message);
        if (match != null && match.groupCount > 0) {
          final missingCol = match.group(1)!;
          print('Missing column detected: ' + missingCol);
          dummyOrder.remove(missingCol);
        } else {
           print('PostgrestException PGRST204 but could not parse missing column: ' + e.message);
           break;
        }
      } else {
        print('Other PostgrestException: ' + e.message);
        break;
      }
    } catch (e) {
      print('Other Exception: ' + e.toString());
      break;
    }
  }
}
