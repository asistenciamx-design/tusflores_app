import 'package:flutter/material.dart';

class BankMethod {
  final String bankName;
  final String accountType;
  final String holderName;
  final String accountNumber;
  final String clabe;

  const BankMethod({required this.bankName, required this.accountType, required this.holderName, required this.accountNumber, required this.clabe});

  Map<String, dynamic> toJson() => {
    'bank_name': bankName,
    'account_type': accountType,
    'holder_name': holderName,
    'account_number': accountNumber,
    'clabe': clabe,
  };

  factory BankMethod.fromJson(Map<String, dynamic> json) => BankMethod(
    bankName: json['bank_name'] ?? '',
    accountType: json['account_type'] ?? '',
    holderName: json['holder_name'] ?? '',
    accountNumber: json['account_number'] ?? '',
    clabe: json['clabe'] ?? '',
  );
}

class LinkMethod {
  final String serviceName;
  final String url;

  const LinkMethod({required this.serviceName, required this.url});

  Map<String, dynamic> toJson() => {
    'service_name': serviceName,
    'url': url,
  };

  factory LinkMethod.fromJson(Map<String, dynamic> json) => LinkMethod(
    serviceName: json['service_name'] ?? '',
    url: json['url'] ?? '',
  );
}

class ScheduleEntry {
  TimeOfDay start;
  TimeOfDay end;
  Set<int> days;

  ScheduleEntry({required this.start, required this.end, required this.days});

  Map<String, dynamic> toJson() => {
    'start_hour': start.hour,
    'start_minute': start.minute,
    'end_hour': end.hour,
    'end_minute': end.minute,
    'days': days.toList(),
  };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
    start: TimeOfDay(hour: json['start_hour'] ?? 9, minute: json['start_minute'] ?? 0),
    end: TimeOfDay(hour: json['end_hour'] ?? 18, minute: json['end_minute'] ?? 0),
    days: Set<int>.from(json['days'] ?? []),
  );
}

class DeliveryRange {
  String label;
  TimeOfDay start;
  TimeOfDay end;
  Set<int> days;

  DeliveryRange({
    required this.label,
    required this.start,
    required this.end,
    required this.days,
  });

  String get timeLabel {
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${fmt(start)} \u2013 ${fmt(end)}';
  }

  String get fullLabel => '$label  \u2022  $timeLabel';

  Map<String, dynamic> toJson() => {
    'label': label,
    'start_hour': start.hour,
    'start_minute': start.minute,
    'end_hour': end.hour,
    'end_minute': end.minute,
    'days': days.toList(),
  };

  factory DeliveryRange.fromJson(Map<String, dynamic> json) => DeliveryRange(
    label: json['label'] ?? '',
    start: TimeOfDay(hour: json['start_hour'] ?? 8, minute: json['start_minute'] ?? 0),
    end: TimeOfDay(hour: json['end_hour'] ?? 14, minute: json['end_minute'] ?? 0),
    days: Set<int>.from(json['days'] ?? []),
  );
}

class ShippingRate {
  String? label;
  String? estado;
  String? ciudad;
  double costo;

  ShippingRate({this.label, this.estado, this.ciudad, this.costo = 0.0});

  Map<String, dynamic> toJson() => {
    'label': label,
    'estado': estado,
    'ciudad': ciudad,
    'costo': costo,
  };

  factory ShippingRate.fromJson(Map<String, dynamic> json) => ShippingRate(
    label: json['label'],
    estado: json['estado'],
    ciudad: json['ciudad'],
    costo: (json['costo'] ?? 0.0).toDouble(),
  );
}

class ShopSettingsModel {
  final Map<String, dynamic>? rawData;

  // Branch Info
  final String? branchImagePath;
  final String? country;
  final String? state;
  final String? city;
  final String? address;
  final String? mapsUrl;
  final String? references;
  final String? phone;
  final String? whatsapp;
  final bool showMapOnProfile;

  // Extracted lists
  final List<ScheduleEntry> storeHours;
  final List<DeliveryRange> deliveryRanges;
  final List<ShippingRate> shippingRates;
  final List<BankMethod> bankMethods;
  final List<LinkMethod> linkMethods;

  ShopSettingsModel({
    required this.storeHours,
    required this.deliveryRanges,
    required this.shippingRates,
    this.bankMethods = const [],
    this.linkMethods = const [],
    this.branchImagePath,
    this.country,
    this.state,
    this.city,
    this.address,
    this.mapsUrl,
    this.references,
    this.phone,
    this.whatsapp,
    this.showMapOnProfile = false,
    this.rawData,
  });

  factory ShopSettingsModel.fromJson(Map<String, dynamic> json) {
    List<ScheduleEntry> hours = [];
    if (json['store_hours'] != null) {
      hours = (json['store_hours'] as List).map((e) => ScheduleEntry.fromJson(e)).toList();
    }
    
    List<DeliveryRange> ranges = [];
    if (json['delivery_ranges'] != null) {
      ranges = (json['delivery_ranges'] as List).map((e) => DeliveryRange.fromJson(e)).toList();
    }
    
    List<ShippingRate> rates = [];
    if (json['shipping_rates'] != null) {
      rates = (json['shipping_rates'] as List).map((e) => ShippingRate.fromJson(e)).toList();
    }
    
    List<BankMethod> banks = [];
    if (json['bank_methods'] != null) {
      banks = (json['bank_methods'] as List).map((e) => BankMethod.fromJson(e)).toList();
    }
    
    List<LinkMethod> links = [];
    if (json['link_methods'] != null) {
      links = (json['link_methods'] as List).map((e) => LinkMethod.fromJson(e)).toList();
    }

    return ShopSettingsModel(
      storeHours: hours,
      deliveryRanges: ranges,
      shippingRates: rates,
      bankMethods: banks,
      linkMethods: links,
      branchImagePath: json['branch_image_path'],
      country: json['country'],
      state: json['state'],
      city: json['city'],
      address: json['address'],
      mapsUrl: json['maps_url'],
      references: json['references'],
      phone: json['phone'],
      whatsapp: json['whatsapp'],
      showMapOnProfile: json['show_map_on_profile'] ?? false,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'store_hours': storeHours.map((e) => e.toJson()).toList(),
    'delivery_ranges': deliveryRanges.map((e) => e.toJson()).toList(),
    'shipping_rates': shippingRates.map((e) => e.toJson()).toList(),
    'bank_methods': bankMethods.map((e) => e.toJson()).toList(),
    'link_methods': linkMethods.map((e) => e.toJson()).toList(),
    'branch_image_path': branchImagePath,
    'country': country,
    'state': state,
    'city': city,
    'address': address,
    'maps_url': mapsUrl,
    'references': references,
    'phone': phone,
    'whatsapp': whatsapp,
    'show_map_on_profile': showMapOnProfile,
  };
}
