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
import '../../features/customer/presentation/screens/public_customer_main_layout.dart';
import '../../features/customer/presentation/screens/customer_branch_screen.dart';
import '../../features/customer/presentation/screens/customer_about_us_screen.dart';
import '../../features/customer/presentation/screens/customer_faq_screen.dart';
import '../../features/customer/presentation/screens/customer_product_detail_screen.dart';
import '../../features/customer/presentation/screens/customer_order_form_screen.dart';
import '../../features/customer/presentation/screens/customer_order_summary_screen.dart';
import '../../features/customer/presentation/screens/customer_payment_methods_screen.dart';
import '../../features/catalog/presentation/screens/catalog_message_screen.dart';
import '../../features/catalog/presentation/screens/catalog_screen.dart' show ProductItem;
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
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final product = extra?['product'] as ProductItem?;
        final shopId = extra?['shopId'] as String?;
        final allProducts = extra?['allProducts'] as List<ProductItem>?;
        return CustomerProductDetailScreen(product: product, shopId: shopId, allProducts: allProducts);
      },
    ),
    GoRoute(
      path: '/shop/checkout',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final product = extra?['product'] as ProductItem?;
        final shopId = extra?['shopId'] as String?;
        return CustomerOrderFormScreen(product: product, shopId: shopId);
      },
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
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _resolveSlug();
  }

  Future<void> _resolveSlug() async {
    try {
      final decodedSlug = Uri.decodeComponent(widget.slug).toLowerCase().trim();
      debugPrint('[PublicStore] Looking for slug: "$decodedSlug"');

      // Helper for bulletproof matching: removes ALL spaces, hyphens, and special chars.
      // E.g., "Mercado Jamaica's" -> "mercadojamaicas"
      // "Mercado Jamaican" -> "mercadojamaican"
      // "tus-flores" -> "tusflores"
      String normalize(String s) {
        return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      final targetNormalized = normalize(decodedSlug);

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, shop_name');

      Map<String, dynamic>? match;
      for (final p in profiles) {
        final name = (p['shop_name'] ?? '') as String;
        
        // Match against exact generated slug, or the heavily normalized string
        final standardSlug = name.toLowerCase().replaceAll(' ', '-');
        if (standardSlug == decodedSlug || 
            normalize(name) == targetNormalized) {
          match = p;
          break;
        }
      }

      debugPrint('[PublicStore] Match: $match');

      if (!mounted) return;
      if (match != null) {
        setState(() {
          _shopId = match!['id'] as String?;
          _shopName = (match!['shop_name'] ?? match!['full_name'] ?? '') as String;
        });
      } else {
        // Collect all available shop names to show on the debug screen
        final availableNames = profiles.map((p) => "'${p['shop_name']}'").join(', ');
        setState(() {
          _notFound = true;
          _debugInfo = '❌ Sin coincidencias.\nSlug buscado: "$targetNormalized"\nDisponibles: [$availableNames]';
        });
      }
    } catch (e) {
      debugPrint('[PublicStore] ERROR: $e');
      if (mounted) {
        setState(() {
          _notFound = true;
          _debugInfo = '⚠️ Error Supabase: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '--- INFO TÉCNICA (pantallazo para soporte) ---\n$_debugInfo',
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace'),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Si todavía estamos intentando cargar (estado inicial)
    if (_shopId == null && _shopName == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return PublicCustomerMainLayout(shopId: _shopId, shopName: _shopName);
  }
}

