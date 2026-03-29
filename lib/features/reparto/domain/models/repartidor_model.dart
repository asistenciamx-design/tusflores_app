class RepartidorModel {
  final String? id;
  final String shopId;
  final String name;
  final String? vehiclePlates;
  final String? vehicleName;
  final DateTime startDate;
  final String status; // 'active' | 'paused'
  final DateTime? createdAt;

  const RepartidorModel({
    this.id,
    required this.shopId,
    required this.name,
    this.vehiclePlates,
    this.vehicleName,
    required this.startDate,
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status == 'active';

  factory RepartidorModel.fromJson(Map<String, dynamic> json) {
    return RepartidorModel(
      id: json['id'] as String?,
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      vehiclePlates: json['vehicle_plates'] as String?,
      vehicleName: json['vehicle_name'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      'name': name,
      if (vehiclePlates != null) 'vehicle_plates': vehiclePlates,
      if (vehicleName != null) 'vehicle_name': vehicleName,
      'start_date': startDate.toIso8601String().split('T').first,
      'status': status,
    };
  }

  RepartidorModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? vehiclePlates,
    String? vehicleName,
    DateTime? startDate,
    String? status,
    DateTime? createdAt,
  }) {
    return RepartidorModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      vehiclePlates: vehiclePlates ?? this.vehiclePlates,
      vehicleName: vehicleName ?? this.vehicleName,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
