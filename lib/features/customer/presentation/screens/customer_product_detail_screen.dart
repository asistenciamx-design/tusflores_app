import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerProductDetailScreen extends StatefulWidget {
  const CustomerProductDetailScreen({super.key});

  @override
  State<CustomerProductDetailScreen> createState() => _CustomerProductDetailScreenState();
}

class _CustomerProductDetailScreenState extends State<CustomerProductDetailScreen> {
  int _selectedImageIndex = 0;

  final List<String> _images = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuB3E2VbL-G75lTtz3Z1_Tf84D_wL10x4tF6C-K0K00fO2n8l2yqT6t7sJcRbbN2uEqOEq9NxtgP0X9K_3y-PjQ4d0f_y9G0K2jQfN8oR1qE5k6Mv7H1r9b2rI5k9wE7T3iX2yB0pY1eU3gV8cT0bN4yR6G3fL2wT9jN6oV4iR9wJ7G9oE7Q8f2R9cE6jR4',
    // Fallback images if the URL fails, though we can just use placeholders or other pics
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCH1K4vO1U0E1J7Y1T3L1Q4rE1A0F5G6J0T5A1H7P2L3D7Y1S0R4P7K3J1E4H4A5G6F0T1U3P2V3A1S0H4T6K0R1Y5D2P1G7C3',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDO0A0K1C6T2F7D4Y5K9A6V1P0J7R4F2E0S5T9Y0J6C3G1L2A4Q9U8S0R3K5A5D2Y8J1H0F4Q1P6J9G0E7A2R3K0T9C6S1F4A',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Detalles del Producto',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
           onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.black, size: 24),
            onPressed: () {
               // TODO: Toggle favorite
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               // Main Image
               ClipRRect(
                 borderRadius: BorderRadius.circular(16),
                 child: Image.network(
                   _images[_selectedImageIndex],
                   height: 350,
                   width: double.infinity,
                   fit: BoxFit.cover,
                   errorBuilder: (ctx, err, stack) => Container(
                     height: 350,
                     width: double.infinity,
                     color: Colors.grey[200],
                     child: const Icon(Icons.local_florist, size: 80, color: Colors.grey),
                   ),
                 ),
               ),
               const SizedBox(height: 12),
               // Gallery
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: List.generate(_images.length, (index) {
                   return _buildGalleryThumbnail(index);
                 }),
               ),
               const SizedBox(height: 24),
               
               // Title
               const Text(
                 'Ramo Amor Eterno',
                 style: TextStyle(
                   fontSize: 26,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 8),

               // Price
               const Text(
                 '\$1,200 MXN',
                 style: TextStyle(
                   fontSize: 20,
                   fontWeight: FontWeight.bold,
                   color: Color(0xFF00C853), // Green typical of price/whatsapp
                 ),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 16),

               // Tags
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 alignment: WrapAlignment.center,
                 children: [
                   _buildTagChip('#Aniversario'),
                   _buildTagChip('#RosasRojas'),
                   _buildTagChip('#Premium'),
                 ],
               ),
               const SizedBox(height: 24),

               // Description
               Text(
                 'Un arreglo espectacular de 24 rosas rojas de invernadero con follaje fino, envueltas en papel francés y listón de seda premium.',
                 style: TextStyle(
                   fontSize: 15,
                   color: Colors.grey[700],
                   height: 1.5,
                 ),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
             onPressed: () {
                context.push('/shop/checkout');
             },
             icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
             label: const Text(
               'Realiza tu Compra',
               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             ),
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFF00E676), // WhatsApp Greenish
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(vertical: 16),
               elevation: 0,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(12),
               ),
             ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryThumbnail(int index) {
     bool isSelected = _selectedImageIndex == index;
     return GestureDetector(
       onTap: () {
         setState(() {
           _selectedImageIndex = index;
         });
       },
       child: Container(
         margin: const EdgeInsets.symmetric(horizontal: 4),
         height: 80,
         width: 80,
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(12),
           border: Border.all(
             color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
             width: 2,
           ),
         ),
         child: ClipRRect(
           borderRadius: BorderRadius.circular(10), // slightly smaller to fit inside border
           child: Image.network(
             _images[index],
             fit: BoxFit.cover,
             errorBuilder: (ctx, err, stack) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.local_florist, color: Colors.grey),
             ),
           ),
         ),
       ),
     );
  }

  Widget _buildTagChip(String label) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
       decoration: BoxDecoration(
         color: const Color(0xFF00E676).withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
       ),
       child: Text(
         label,
         style: const TextStyle(
           color: Color(0xFF00C853), // slightly darker green for text
           fontSize: 13,
           fontWeight: FontWeight.w500,
         ),
       ),
    );
  }
}
