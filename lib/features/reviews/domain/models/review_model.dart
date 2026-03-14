class ReviewModel {
  final String? id;
  final String shopId;
  final String? orderId;
  final String reviewerName;
  final int rating;
  final String? comment;
  final String? shopReply;
  final bool isVerified;
  final bool isVisible;
  final DateTime createdAt;

  const ReviewModel({
    this.id,
    required this.shopId,
    this.orderId,
    required this.reviewerName,
    required this.rating,
    this.comment,
    this.shopReply,
    this.isVerified = false,
    this.isVisible = true,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String?,
      shopId: json['shop_id'] as String? ?? '',
      orderId: json['order_id'] as String?,
      reviewerName: json['reviewer_name'] as String? ?? 'Cliente',
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String?,
      shopReply: json['shop_reply'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      if (orderId != null) 'order_id': orderId,
      'reviewer_name': reviewerName,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      'is_verified': isVerified,
      'is_visible': isVisible,
    };
  }
}
