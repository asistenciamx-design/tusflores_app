import 'package:flutter/material.dart';

/// Mutable gift/extra product that florists can customize.
class GiftExtra {
  String name;
  double price;
  IconData icon;
  Color color;
  bool isActive;

  GiftExtra({
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
    this.isActive = true,
  });
}

/// Singleton that holds the customizable gift/extra products.
/// These are "comodín" products shown to clients when placing orders.
/// Florists can rename, reprice, enable or disable each one.
class GiftsService {
  GiftsService._();
  static final GiftsService instance = GiftsService._();

  final List<GiftExtra> gifts = [
    GiftExtra(name: 'Globo',       price: 90,  icon: Icons.card_giftcard,  color: const Color(0xFFEC407A), isActive: true),
    GiftExtra(name: 'Chocolates',  price: 200, icon: Icons.cookie_outlined, color: const Color(0xFF795548), isActive: true),
    GiftExtra(name: 'Peluche',     price: 300, icon: Icons.toys_outlined,   color: const Color(0xFFFFA726), isActive: true),
  ];

  /// Only returns active gifts — these are the ones visible to clients.
  List<GiftExtra> get activeGifts => gifts.where((g) => g.isActive).toList();
}
