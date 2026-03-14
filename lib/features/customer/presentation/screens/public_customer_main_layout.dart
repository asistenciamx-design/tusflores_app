import 'package:flutter/material.dart';
import 'customer_catalog_screen.dart';
import 'customer_branch_screen.dart';
import 'customer_about_us_screen.dart';
import 'customer_faq_screen.dart';

class PublicCustomerMainLayout extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  
  const PublicCustomerMainLayout({
    super.key,
    this.shopId,
    this.shopName,
  });

  @override
  State<PublicCustomerMainLayout> createState() => _PublicCustomerMainLayoutState();
}

class _PublicCustomerMainLayoutState extends State<PublicCustomerMainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_currentIndex) {
      case 0:
        child = CustomerCatalogScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          onNavigateToNosotros: () => setState(() => _currentIndex = 2),
        );
        break;
      case 1:
        child = CustomerBranchScreen(shopId: widget.shopId);
        break;
      case 2:
        child = CustomerAboutUsScreen(shopId: widget.shopId);
        break;
      case 3:
        child = CustomerFaqScreen(shopId: widget.shopId);
        break;
      default:
        child = CustomerCatalogScreen(shopId: widget.shopId, shopName: widget.shopName);
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Tienda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: 'Sucursal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            activeIcon: Icon(Icons.info),
            label: 'Nosotros',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            activeIcon: Icon(Icons.help),
            label: 'Atención',
          ),
        ],
      ),
    );
  }
}
