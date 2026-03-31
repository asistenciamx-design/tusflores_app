import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/main/presentation/screens/main_layout.dart';
import '../../features/admin/presentation/screens/admin_layout.dart';

import '../../features/auth/presentation/screens/create_account_screen.dart';
import '../../features/auth/presentation/screens/shop_name_claim_screen.dart';
import '../../features/auth/presentation/screens/connect_whatsapp_screen.dart';
import '../../features/auth/presentation/screens/verify_code_screen.dart';
import '../../features/auth/presentation/screens/account_verified_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';

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
import '../../features/customer/presentation/screens/order_tracking_screen.dart';
import '../../features/reviews/presentation/screens/review_form_screen.dart';
import '../../features/reviews/presentation/screens/shop_reviews_manage_screen.dart';
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_screen.dart';
import '../services/seo_service.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final path = state.uri.path;
    const protectedPaths = ['/', '/reviews/manage', '/admin'];
    // Si ya está autenticado y va al login, redirigir al home
    if (isLoggedIn && path == '/login') return '/';
    if (protectedPaths.contains(path) && !isLoggedIn) return '/login';
    return null;
  },
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
      path: '/reset-password',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return ResetPasswordScreen(code: code);
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainLayout(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminLayout(),
    ),
    // ── Rutas legales (públicas, sin autenticación) ────────────────────────
    GoRoute(
      path: '/privacidad',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terminos',
      builder: (context, state) => const TermsScreen(),
    ),
    // ── Ruta pública de la tienda ──────────────────────────────────────────
    // Visitantes acceden por: tusflores.app/{pais}/{slug}
    // Países soportados: mx, co, ar
    GoRoute(
      path: '/:pais/:slug',
      builder: (context, state) {
        final pais = state.pathParameters['pais'] ?? '';
        final slug = state.pathParameters['slug'] ?? '';
        return _PublicStoreLoader(pais: pais, slug: slug);
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
        final giftProducts = (extra?['giftProducts'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return CustomerOrderFormScreen(
            product: product, shopId: shopId, giftProducts: giftProducts);
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
    GoRoute(
      path: '/seguimiento/:folio',
      builder: (context, state) {
        final folio = state.pathParameters['folio'] ?? '';
        return OrderTrackingScreen(folio: folio);
      },
    ),
    GoRoute(
      path: '/reviews/manage',
      builder: (context, state) => const ShopReviewsManageScreen(),
    ),
    GoRoute(
      path: '/resena',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ReviewFormScreen(
          shopId: extra?['shopId'] as String? ?? '',
          shopName: extra?['shopName'] as String? ?? 'La florería',
          orderId: extra?['orderId'] as String?,
          customerName: extra?['customerName'] as String?,
        );
      },
    ),
  ],
);

// ── Widget auxiliar: resuelve el slug y carga la tienda pública ────────────
class _PublicStoreLoader extends StatefulWidget {
  final String pais;
  final String slug;
  const _PublicStoreLoader({required this.pais, required this.slug});

  @override
  State<_PublicStoreLoader> createState() => _PublicStoreLoaderState();
}

class _PublicStoreLoaderState extends State<_PublicStoreLoader>
    with SingleTickerProviderStateMixin {
  String? _shopId;
  String? _shopName;
  bool _notFound = false;

  late final AnimationController _shimmerCtrl;

  static const _validCountries = {'mx', 'co', 'ar'};

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _resolveSlug();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateSeo(String? shopId, String shopName) async {
    if (shopId == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('average_rating, review_count')
          .eq('id', shopId)
          .maybeSingle();
      final rating = (profile?['average_rating'] as num?)?.toDouble() ?? 0;
      final count = profile?['review_count'] as int? ?? 0;
      updateShopJsonLd(
        shopName: shopName,
        ratingValue: rating,
        reviewCount: count,
      );
    } catch (_) {}
  }

  Future<void> _resolveSlug() async {
    final pais = widget.pais.toLowerCase().trim();
    final slug = Uri.decodeComponent(widget.slug).toLowerCase().trim();

    // Validar país
    if (!_validCountries.contains(pais)) {
      if (mounted) setState(() => _notFound = true);
      return;
    }

    try {
      // 1. Buscar en slugs_registry (nuevo sistema)
      final registryMatch = await Supabase.instance.client
          .from('slugs_registry')
          .select('entity_type, entity_id')
          .eq('pais', pais)
          .eq('slug', slug)
          .maybeSingle();

      if (!mounted) return;

      if (registryMatch != null) {
        final entityId = registryMatch['entity_id'] as String;
        // Obtener nombre de la tienda del perfil
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('shop_name')
            .eq('id', entityId)
            .maybeSingle();

        if (!mounted) return;
        final resolvedName = (profile?['shop_name'] ?? '') as String;
        setState(() {
          _shopId = entityId;
          _shopName = resolvedName;
        });
        _updateSeo(entityId, resolvedName);
        return;
      }

      // 2. Fallback: buscar por slug generado del shop_name (compatibilidad)
      final normalizedSlug = slug.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final legacyMatch = await Supabase.instance.client
          .from('profiles')
          .select('id, shop_name')
          .eq('slug', normalizedSlug)
          .maybeSingle();

      if (!mounted) return;
      if (legacyMatch != null) {
        final resolvedShopName = (legacyMatch['shop_name'] ?? '') as String;
        setState(() {
          _shopId = legacyMatch['id'] as String?;
          _shopName = resolvedShopName;
        });
        _updateSeo(legacyMatch['id'] as String?, resolvedShopName);
      } else {
        setState(() => _notFound = true);
      }
    } catch (e) {
      if (mounted) setState(() => _notFound = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) return const _NotFoundScreen();

    if (_shopId == null && _shopName == null) {
      return _SkeletonLoading(animation: _shimmerCtrl);
    }

    return PublicCustomerMainLayout(shopId: _shopId, shopName: _shopName);
  }
}

// ── Pantalla 404 ──────────────────────────────────────────────────────────────
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.storefront_outlined,
                    size: 48, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pagina no encontrada',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 12),
              Text(
                'El enlace que seguiste no existe o ya no esta disponible.\nVerifica que la URL sea correcta.',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () {
                  // Go to home / landing
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Volver'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton loading mientras se resuelve el slug ─────────────────────────────
class _SkeletonLoading extends StatefulWidget {
  final AnimationController animation;
  const _SkeletonLoading({required this.animation});

  @override
  State<_SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<_SkeletonLoading> {
  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_tick);
  }

  @override
  void dispose() {
    widget.animation.removeListener(_tick);
    super.dispose();
  }

  void _tick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = ColorTween(
      begin: Colors.grey.shade200,
      end: Colors.grey.shade100,
    ).evaluate(widget.animation)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 180,
                  height: 24,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < 3; i++) ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

