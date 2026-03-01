import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/main/presentation/screens/main_layout.dart';

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
  initialLocation: '/login', // Starting at the Onboarding flow
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
