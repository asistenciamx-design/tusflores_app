import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/main/presentation/screens/main_layout.dart';
import '../../features/auth/domain/repositories/profile_repository.dart';

import '../../features/auth/presentation/screens/create_account_screen.dart';
import '../../features/auth/presentation/screens/shop_name_claim_screen.dart';
import '../../features/auth/presentation/screens/connect_whatsapp_screen.dart';
import '../../features/auth/presentation/screens/verify_code_screen.dart';
import '../../features/auth/presentation/screens/account_verified_screen.dart';

import '../../features/customer/presentation/screens/customer_main_layout.dart';
import '../../features/customer/presentation/screens/customer_catalog_screen.dart';
import '../../features/customer/presentation/screens/customer_branch_screen.dart';
import '../../features/customer/presentation/screens/customer_about_us_screen.dart';
import '../../features/customer/presentation/screens/customer_faq_screen.dart';
import '../../features/customer/presentation/screens/customer_product_detail_screen.dart';
import '../../features/customer/presentation/screens/customer_order_form_screen.dart';
import '../../features/customer/presentation/screens/customer_order_summary_screen.dart';
import '../../features/customer/presentation/screens/customer_payment_methods_screen.dart';
import '../../features/catalog/presentation/screens/catalog_message_screen.dart';
import '../../features/orders/domain/models/order_model.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/create-account',
      builder: (context, state) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/shop-claim',
      builder: (context, state) => const ShopNameClaimScreen(),
    ),
    GoRoute(
      path: '/connect-whatsapp',
      builder: (context, state) => const ConnectWhatsAppScreen(),
    ),
    GoRoute(
      path: '/verify-code',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return VerifyCodeScreen(email: email);
      },
    ),
    GoRoute(
      path: '/account-verified',
      builder: (context, state) => const AccountVerifiedScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainLayout(),
    ),
    // ── Ruta pública de la tienda ──────────────────────────────────────────
    // Visitantes acceden por: tusflores.app/mx/{slug}
    GoRoute(
      path: '/mx/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        return _PublicStoreLoader(slug: slug);
      },
    ),
    // ── Rutas del cliente (con barra de navegación inferior) ───────────────
    ShellRoute(
      builder: (context, state, child) {
        return CustomerMainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/shop/catalog',
          builder: (context, state) => const CustomerCatalogScreen(),
        ),
        GoRoute(
          path: '/shop/branch',
          builder: (context, state) => const CustomerBranchScreen(),
        ),
        GoRoute(
          path: '/shop/about',
          builder: (context, state) => const CustomerAboutUsScreen(),
        ),
        GoRoute(
          path: '/shop/faq',
          builder: (context, state) => const CustomerFaqScreen(),
        ),
      ],
    ),
    // Rutas de flujo de pedido (sin barra de navegación inferior)
    GoRoute(
      path: '/shop/product',
      builder: (context, state) => const CustomerProductDetailScreen(),
    ),
    GoRoute(
      path: '/shop/checkout',
      builder: (context, state) => const CustomerOrderFormScreen(),
    ),
    GoRoute(
      path: '/shop/summary',
      builder: (context, state) {
        final order = state.extra as OrderModel?;
        if (order == null) {
          return const Scaffold(body: Center(child: Text('Error: Falta la información del pedido')));
        }
        return CustomerOrderSummaryScreen(order: order);
      },
    ),
    GoRoute(
      path: '/shop/payment-methods',
      builder: (context, state) {
        final shopId = state.extra as String? ?? '';
        return CustomerPaymentMethodsScreen(shopId: shopId);
      },
    ),
    GoRoute(
      path: '/shop/catalog-message',
      builder: (context, state) => const CatalogMessageScreen(),
    ),
  ],
);

// ── Widget auxiliar: resuelve el slug y carga la tienda pública ────────────
class _PublicStoreLoader extends StatefulWidget {
  final String slug;
  const _PublicStoreLoader({required this.slug});

  @override
  State<_PublicStoreLoader> createState() => _PublicStoreLoaderState();
}

class _PublicStoreLoaderState extends State<_PublicStoreLoader> {
  String? _shopId;
  String? _shopName;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _resolveSlug();
  }

  Future<void> _resolveSlug() async {
    try {
      // URL-decode the slug in case the browser encoded special chars
      final decodedSlug = Uri.decodeComponent(widget.slug);
      debugPrint('[PublicStore] Resolving slug: "$decodedSlug"');

      // Query Supabase directly (works with anon key)
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id, shop_name, full_name')
          .eq('shop_name', decodedSlug)
          .maybeSingle();

      debugPrint('[PublicStore] Result: $result');

      if (!mounted) return;
      if (result == null) {
        setState(() => _notFound = true);
      } else {
        setState(() {
          _shopId = result['id'] as String?;
          _shopName = (result['shop_name'] ?? result['full_name'] ?? '') as String;
        });
      }
    } catch (e) {
      debugPrint('[PublicStore] ERROR resolving slug: $e');
      if (mounted) setState(() => _notFound = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_florist_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Florería no encontrada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifica que el enlace sea correcto.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    }
    if (_shopId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return CustomerCatalogScreen(shopId: _shopId, shopName: _shopName);
  }
}
