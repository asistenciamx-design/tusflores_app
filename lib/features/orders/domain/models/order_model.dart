import 'package:flutter/material.dart';

enum OrderStatus { waiting, processing, inTransit, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  /// Valor que se guarda en la BD.
  String get dbValue {
    switch (this) {
      case OrderStatus.waiting:    return 'waiting';
      case OrderStatus.processing: return 'processing';
      case OrderStatus.inTransit:  return 'in_transit';
      case OrderStatus.delivered:  return 'delivered';
      case OrderStatus.cancelled:  return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.waiting:    return 'En espera';
      case OrderStatus.processing: return 'Elaborando';
      case OrderStatus.inTransit:  return 'En tránsito';
      case OrderStatus.delivered:  return 'Entregado';
      case OrderStatus.cancelled:  return 'Cancelado';
    }
  }

  Color get chipColor {
    switch (this) {
      case OrderStatus.waiting:    return const Color(0xFFF59E0B);
      case OrderStatus.processing: return const Color(0xFF3B82F6);
      case OrderStatus.inTransit:  return const Color(0xFF8B5CF6);
      case OrderStatus.delivered:  return const Color(0xFF10B981);
      case OrderStatus.cancelled:  return const Color(0xFFEF4444);
    }
  }

  IconData get chipIcon {
    switch (this) {
      case OrderStatus.waiting:    return Icons.schedule_rounded;
      case OrderStatus.processing: return Icons.spa_outlined;
      case OrderStatus.inTransit:  return Icons.local_shipping_outlined;
      case OrderStatus.delivered:  return Icons.check_circle_rounded;
      case OrderStatus.cancelled:  return Icons.cancel_outlined;
    }
  }
}

class OrderModel {
  final String? id;
  final String shopId;
  final String folio;
  final String productName;
  final String customerName;
  final String customerPhone;
  final int quantity;
  final double price;
  OrderStatus status;
  final DateTime createdAt;
  final DateTime saleDate;
  final String deliveryInfo;

  // UI mapping fields - these shouldn't be serialized to DB, just populated locally
  Color? iconBgColor;
  Color? iconColor;
  IconData? icon;

  bool isPaid;
  String? paymentMethod;
  List<String> completionPhotos;
  
  final double shippingCost;
  final String deliveryMethod;
  final bool isAnonymous;
  final String? recipientName;
  final String? recipientPhone;
  final String? dedicationMessage;
  final String? deliveryAddress;
  final String? deliveryReferences;
  final String? deliveryLocationType;
  final String? deliveryState;
  final String? deliveryCity;
  final String? buyerName;
  final String? buyerWhatsapp;
  final String? buyerEmail;

  OrderModel({
    this.id,
    required this.shopId,
    required this.folio,
    required this.productName,
    required this.customerName,
    required this.customerPhone,
    required this.quantity,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.saleDate,
    required this.deliveryInfo,
    this.iconBgColor,
    this.iconColor,
    this.icon,
    this.isPaid = false,
    this.paymentMethod,
    this.completionPhotos = const [],
    this.shippingCost = 0.0,
    this.deliveryMethod = 'Envío a domicilio',
    this.isAnonymous = false,
    this.recipientName,
    this.recipientPhone,
    this.dedicationMessage,
    this.deliveryAddress,
    this.deliveryReferences,
    this.deliveryLocationType,
    this.deliveryState,
    this.deliveryCity,
    this.buyerName,
    this.buyerWhatsapp,
    this.buyerEmail,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String?,
      shopId: json['shop_id'] as String? ?? '',
      folio: json['folio'] as String? ?? '#0000',
      productName: json['product_name'] as String? ?? 'Producto Desconocido',
      customerName: json['customer_name'] as String? ?? 'Cliente',
      customerPhone: json['customer_phone'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String?),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      saleDate: json['sale_date'] != null ? DateTime.parse(json['sale_date']) : DateTime.now(),
      deliveryInfo: json['delivery_info'] as String? ?? '',
      isPaid: json['is_paid'] as bool? ?? false,
      paymentMethod: json['payment_method'] as String?,
      completionPhotos: (json['completion_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      deliveryMethod: json['delivery_method'] as String? ?? 'Envío a domicilio',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      dedicationMessage: json['dedication_message'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryReferences: json['delivery_references'] as String?,
      deliveryLocationType: json['delivery_location_type'] as String?,
      deliveryState: json['delivery_state'] as String?,
      deliveryCity: json['delivery_city'] as String?,
      buyerName: json['buyer_name'] as String?,
      buyerWhatsapp: json['buyer_whatsapp'] as String?,
      buyerEmail: json['buyer_email'] as String?,
      // Map UI colors for displaying correctly in the app
      iconBgColor: const Color(0xFFF5F5F5),
      iconColor: Colors.black87,
      icon: Icons.local_florist,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      'florist_id': shopId,
      'folio': folio,
      'product_name': productName,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'quantity': quantity,
      'price': price,
      'total_price': total,
      'status': status.dbValue,
      'created_at': createdAt.toIso8601String(),
      'sale_date': saleDate.toIso8601String(),
      'delivery_info': deliveryInfo,
      'is_paid': isPaid,
      'payment_method': paymentMethod,
      'shipping_cost': shippingCost,
      'delivery_method': deliveryMethod,
      'is_anonymous': isAnonymous,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'dedication_message': dedicationMessage,
      'delivery_address': deliveryAddress,
      'delivery_references': deliveryReferences,
      'delivery_location_type': deliveryLocationType,
      'delivery_state': deliveryState,
      'delivery_city': deliveryCity,
      'buyer_name': buyerName,
      'buyer_whatsapp': buyerWhatsapp,
      'buyer_email': buyerEmail,
    };
  }

  static OrderStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'waiting':
      case 'pending': // backward compat: pedidos viejos
        return OrderStatus.waiting;
      case 'processing': return OrderStatus.processing;
      case 'in_transit': return OrderStatus.inTransit;
      case 'delivered':  return OrderStatus.delivered;
      case 'cancelled':  return OrderStatus.cancelled;
      default:           return OrderStatus.waiting;
    }
  }

  OrderModel copyWith({
    String? id,
    String? shopId,
    String? folio,
    String? productName,
    String? customerName,
    String? customerPhone,
    int? quantity,
    double? price,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? saleDate,
    String? deliveryInfo,
    Color? iconBgColor,
    Color? iconColor,
    IconData? icon,
    bool? isPaid,
    String? paymentMethod,
    List<String>? completionPhotos,
    double? shippingCost,
    String? deliveryMethod,
    bool? isAnonymous,
    String? recipientName,
    String? recipientPhone,
    String? dedicationMessage,
    String? deliveryAddress,
    String? deliveryReferences,
    String? deliveryLocationType,
    String? deliveryState,
    String? deliveryCity,
    String? buyerName,
    String? buyerWhatsapp,
    String? buyerEmail,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      folio: folio ?? this.folio,
      productName: productName ?? this.productName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      saleDate: saleDate ?? this.saleDate,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      iconBgColor: iconBgColor ?? this.iconBgColor,
      iconColor: iconColor ?? this.iconColor,
      icon: icon ?? this.icon,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      completionPhotos: completionPhotos ?? this.completionPhotos,
      shippingCost: shippingCost ?? this.shippingCost,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      dedicationMessage: dedicationMessage ?? this.dedicationMessage,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryReferences: deliveryReferences ?? this.deliveryReferences,
      deliveryLocationType: deliveryLocationType ?? this.deliveryLocationType,
      deliveryState: deliveryState ?? this.deliveryState,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      buyerName: buyerName ?? this.buyerName,
      buyerWhatsapp: buyerWhatsapp ?? this.buyerWhatsapp,
      buyerEmail: buyerEmail ?? this.buyerEmail,
    );
  }

  double get total => quantity * price;
}
