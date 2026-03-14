import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerMainLayout extends StatelessWidget {
  const CustomerMainLayout({
    super.key,
    required this.child,
  });

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/shop/catalog')) {
      return 0;
    }
    if (location.startsWith('/shop/branch')) {
      return 1;
    }
    if (location.startsWith('/shop/about')) {
      return 2;
    }
    if (location.startsWith('/shop/faq')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/shop/catalog');
        break;
      case 1:
        context.go('/shop/branch');
        break;
      case 2:
        context.go('/shop/about');
        break;
      case 3:
        context.go('/shop/faq');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
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
            label: 'Ayuda',
          ),
        ],
      ),
    );
  }
}
