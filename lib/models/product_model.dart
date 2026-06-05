import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductCategory {
  groceries,
  vegetables,
  fruits,
  dairy,
  bakery,
  snacks,
  beverages,
  household,
  personalCare,
  electronics,
  clothing,
  footwear,
  homeDecor,
  kitchenware,
  stationery,
  toys,
  medicines,
  agricultural,
  other,
}

class ProductUnitOption {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final int stockQuantity;

  ProductUnitOption({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.stockQuantity,
  });

  factory ProductUnitOption.fromMap(Map<String, dynamic> map) {
    return ProductUnitOption(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'stockQuantity': stockQuantity,
    };
  }
}

class CompetitorPrice {
  final String competitorName;
  final double price;
  final DateTime updatedAt;

  CompetitorPrice({
    required this.competitorName,
    required this.price,
    required this.updatedAt,
  });

  factory CompetitorPrice.fromMap(Map<String, dynamic> map) {
    return CompetitorPrice(
      competitorName: map['competitorName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      updatedAt: ProductModel._parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'competitorName': competitorName,
      'price': price,
      'updatedAt': updatedAt,
    };
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final double? discountPercentage;
  final String unit;
  final String category;
  final String subCategory;
  final String shopId;
  final String shopName;
  final String imageUrl;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final int stockQuantity;
  final int minimumStock; // Feature 12
  final bool isAvailable;
  final bool isFeatured;
  final bool isOnSale;
  final bool isNewArrival;
  final bool isTrending;
  final Map<String, dynamic> specifications;
  final List<String> tags;
  final String barcode;
  final String? brand;
  final String? origin;
  final DateTime? expiryDate;
  final bool isExpired; // Feature 13
  final List<CompetitorPrice> competitorPrices; // Feature 14
  final double? costPrice; // Feature 14
  final String? pricingStrategy; // Feature 14
  final DateTime? lastPriceUpdate; // Feature 14
  final double? weight;
  final String weightUnit;
  final int minOrderQuantity;
  final int maxOrderQuantity;
  final String district;
  final String village;
  final GeoPoint? sourceLocation;
  final String? sourceName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductUnitOption> unitOptions;
  final double? lightningDealPrice;
  final DateTime? lightningDealEndTime;
  final bool isGroupBuyEligible; // Feature 15
  final String? farmStory; // Feature 16: Deep transparency
  final String? farmerName; // Step 11.3
  final String? farmerImageUrl; // Step 11.3
  final DateTime? harvestDate; // Step 11.4
  final bool isOrganicCertified; // Step 11.5
  final Map<String, int> branchStock;
  final Map<String, Map<String, dynamic>> branchLocations;
  final String? shelfPhotoUrl;
  final DateTime? shelfPhotoUpdatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.discountPercentage,
    required this.unit,
    required this.category,
    this.subCategory = '',
    required this.shopId,
    required this.shopName,
    required this.imageUrl,
    this.images = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.stockQuantity,
    this.minimumStock = 10, // Feature 12 Default
    this.isAvailable = true,
    this.isFeatured = false,
    this.isOnSale = false,
    this.isNewArrival = false,
    this.isTrending = false,
    this.specifications = const {},
    this.tags = const [],
    this.barcode = '',
    this.brand,
    this.origin,
    this.expiryDate,
    this.isExpired = false, // Feature 13
    this.competitorPrices = const [], // Feature 14
    this.costPrice, // Feature 14
    this.pricingStrategy, // Feature 14
    this.lastPriceUpdate, // Feature 14
    this.weight,
    this.weightUnit = 'kg',
    this.minOrderQuantity = 1,
    this.maxOrderQuantity = 100,
    required this.district,
    this.village = '',
    this.sourceLocation,
    this.sourceName,
    required this.createdAt,
    required this.updatedAt,
    this.unitOptions = const [],
    this.lightningDealPrice,
    this.lightningDealEndTime,
    this.isGroupBuyEligible = false,
    this.farmStory,
    this.farmerName,
    this.farmerImageUrl,
    this.harvestDate,
    this.isOrganicCertified = false,
    this.branchStock = const {},
    this.branchLocations = const {},
    this.shelfPhotoUrl,
    this.shelfPhotoUpdatedAt,
  });

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (_) {}
    return null;
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble(),
      unit: map['unit'] ?? 'piece',
      category: map['category'] ?? 'other',
      subCategory: map['subCategory'] ?? '',
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      stockQuantity: map['stockQuantity'] ?? 0,
      minimumStock: map['minimumStock'] ?? 10,
      isAvailable: map['isAvailable'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      isOnSale: map['isOnSale'] ?? false,
      isNewArrival: map['isNewArrival'] ?? false,
      isTrending: map['isTrending'] ?? false,
      specifications: Map<String, dynamic>.from(map['specifications'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
      barcode: map['barcode'] ?? '',
      brand: map['brand'],
      origin: map['origin'],
      expiryDate: _parseDate(map['expiryDate']),
      isExpired: map['isExpired'] ?? false,
      competitorPrices:
          (map['competitorPrices'] as List?)
              ?.map(
                (x) => CompetitorPrice.fromMap(Map<String, dynamic>.from(x)),
              )
              .toList() ??
          const [],
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      pricingStrategy: map['pricingStrategy'],
      lastPriceUpdate: _parseDate(map['lastPriceUpdate']),
      weight: (map['weight'] as num?)?.toDouble(),
      weightUnit: map['weightUnit'] ?? 'kg',
      minOrderQuantity: map['minOrderQuantity'] ?? 1,
      maxOrderQuantity: map['maxOrderQuantity'] ?? 100,
      district: map['district'] ?? '',
      village: map['village'] ?? '',
      sourceLocation: map['sourceLocation'] as GeoPoint?,
      sourceName: map['sourceName'],
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      unitOptions:
          (map['unitOptions'] as List?)
              ?.map(
                (x) => ProductUnitOption.fromMap(Map<String, dynamic>.from(x)),
              )
              .toList() ??
          const [],
      lightningDealPrice: (map['lightningDealPrice'] as num?)?.toDouble(),
      lightningDealEndTime: _parseDate(map['lightningDealEndTime']),
      farmStory: map['farmStory'],
      farmerName: map['farmerName'],
      farmerImageUrl: map['farmerImageUrl'],
      harvestDate: _parseDate(map['harvestDate']),
      isOrganicCertified: map['isOrganicCertified'] ?? false,
      branchStock:
          (map['branchStock'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          const {},
      branchLocations:
          (map['branchLocations'] as Map<dynamic, dynamic>?)?.map((k, v) {
            if (v is Map) {
              return MapEntry(k.toString(), Map<String, dynamic>.from(v));
            } else if (v is String) {
              final regAisle = RegExp(
                r'Aisle\s+([A-Za-z0-9]+)',
                caseSensitive: false,
              );
              final regShelf = RegExp(r'Shelf\s+(\d+)', caseSensitive: false);
              final matchAisle = regAisle.firstMatch(v);
              final matchShelf = regShelf.firstMatch(v);
              final zoneStr = matchAisle?.group(1) ?? 'A';
              final shelfNum = int.tryParse(matchShelf?.group(1) ?? '1') ?? 1;
              return MapEntry(k.toString(), {
                'zone': zoneStr,
                'aisle': 1,
                'shelf': shelfNum,
                'bin': 1,
              });
            } else {
              return MapEntry(k.toString(), <String, dynamic>{});
            }
          }) ??
          const {},
      shelfPhotoUrl: map['shelfPhotoUrl'],
      shelfPhotoUpdatedAt: _parseDate(map['shelfPhotoUpdatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'unit': unit,
      'category': category,
      'subCategory': subCategory,
      'shopId': shopId,
      'shopName': shopName,
      'imageUrl': imageUrl,
      'images': images,
      'rating': rating,
      'reviewCount': reviewCount,
      'stockQuantity': stockQuantity,
      'minimumStock': minimumStock,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isOnSale': isOnSale,
      'isNewArrival': isNewArrival,
      'isTrending': isTrending,
      'specifications': specifications,
      'tags': tags,
      'barcode': barcode,
      'brand': brand,
      'origin': origin,
      'expiryDate': expiryDate,
      'isExpired': isExpired,
      'competitorPrices': competitorPrices.map((x) => x.toMap()).toList(),
      'costPrice': costPrice,
      'pricingStrategy': pricingStrategy,
      'lastPriceUpdate': lastPriceUpdate,
      'weight': weight,
      'weightUnit': weightUnit,
      'minOrderQuantity': minOrderQuantity,
      'maxOrderQuantity': maxOrderQuantity,
      'district': district,
      'village': village,
      'sourceLocation': sourceLocation,
      'sourceName': sourceName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'unitOptions': unitOptions.map((x) => x.toMap()).toList(),
      'lightningDealPrice': lightningDealPrice,
      'lightningDealEndTime': lightningDealEndTime?.toIso8601String(),
      'farmStory': farmStory,
      'farmerName': farmerName,
      'farmerImageUrl': farmerImageUrl,
      'harvestDate': harvestDate?.toIso8601String(),
      'isOrganicCertified': isOrganicCertified,
      'branchStock': branchStock,
      'branchLocations': branchLocations,
      'shelfPhotoUrl': shelfPhotoUrl,
      'shelfPhotoUpdatedAt': shelfPhotoUpdatedAt?.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    double? discountPercentage,
    String? unit,
    String? category,
    String? subCategory,
    String? shopId,
    String? shopName,
    String? imageUrl,
    List<String>? images,
    double? rating,
    int? reviewCount,
    int? stockQuantity,
    int? minimumStock,
    bool? isAvailable,
    bool? isFeatured,
    bool? isOnSale,
    bool? isNewArrival,
    bool? isTrending,
    Map<String, dynamic>? specifications,
    List<String>? tags,
    String? barcode,
    String? brand,
    String? origin,
    DateTime? expiryDate,
    bool? isExpired,
    List<CompetitorPrice>? competitorPrices,
    double? costPrice,
    String? pricingStrategy,
    DateTime? lastPriceUpdate,
    double? weight,
    String? weightUnit,
    int? minOrderQuantity,
    int? maxOrderQuantity,
    String? district,
    String? village,
    GeoPoint? sourceLocation,
    String? sourceName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductUnitOption>? unitOptions,
    double? lightningDealPrice,
    DateTime? lightningDealEndTime,
    Map<String, int>? branchStock,
    Map<String, Map<String, dynamic>>? branchLocations,
    String? shelfPhotoUrl,
    DateTime? shelfPhotoUpdatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isOnSale: isOnSale ?? this.isOnSale,
      isNewArrival: isNewArrival ?? this.isNewArrival,
      isTrending: isTrending ?? this.isTrending,
      specifications: specifications ?? this.specifications,
      tags: tags ?? this.tags,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      origin: origin ?? this.origin,
      expiryDate: expiryDate ?? this.expiryDate,
      isExpired: isExpired ?? this.isExpired,
      competitorPrices: competitorPrices ?? this.competitorPrices,
      costPrice: costPrice ?? this.costPrice,
      pricingStrategy: pricingStrategy ?? this.pricingStrategy,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      maxOrderQuantity: maxOrderQuantity ?? this.maxOrderQuantity,
      district: district ?? this.district,
      village: village ?? this.village,
      sourceLocation: sourceLocation ?? this.sourceLocation,
      sourceName: sourceName ?? this.sourceName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unitOptions: unitOptions ?? this.unitOptions,
      lightningDealPrice: lightningDealPrice ?? this.lightningDealPrice,
      lightningDealEndTime: lightningDealEndTime ?? this.lightningDealEndTime,
      branchStock: branchStock ?? this.branchStock,
      branchLocations: branchLocations ?? this.branchLocations,
      shelfPhotoUrl: shelfPhotoUrl ?? this.shelfPhotoUrl,
      shelfPhotoUpdatedAt: shelfPhotoUpdatedAt ?? this.shelfPhotoUpdatedAt,
    );
  }

  bool get isLightningDealActive {
    if (lightningDealPrice == null || lightningDealEndTime == null) {
      return false;
    }
    return DateTime.now().isBefore(lightningDealEndTime!);
  }

  double get currentPrice {
    if (isLightningDealActive) {
      return lightningDealPrice!;
    }
    return price;
  }

  double get discountedPrice {
    if (isLightningDealActive) return lightningDealPrice!;
    if (originalPrice != null && originalPrice! > price) {
      return price;
    }
    return price;
  }

  double? get mrp =>
      isLightningDealActive ? (originalPrice ?? price) : originalPrice;

  double get effectiveDiscount {
    if (isLightningDealActive) {
      final basePrice = originalPrice ?? price;
      if (basePrice <= lightningDealPrice!) return 0;
      return ((basePrice - lightningDealPrice!) / basePrice) * 100;
    }
    if (discountPercentage != null) return discountPercentage!;
    if (originalPrice == null || originalPrice! <= price) return 0;
    return ((originalPrice! - price) / originalPrice!) * 100;
  }

  bool get isLocal => village.isNotEmpty || origin?.toLowerCase() == 'local';

  bool get inStock => stockQuantity > 0;

  /// Normalizes price to 1kg/1L for value comparison (Step 13.3)
  double? get normalizedPricePerKg {
    final currentP = currentPrice;
    final String u = unit.toLowerCase();

    if (u.contains('kg')) {
      final double qty = double.tryParse(u.split(' ')[0]) ?? 1.0;
      return currentP / qty;
    } else if (u.contains(' g')) {
      final double qty = double.tryParse(u.split(' ')[0]) ?? 500.0;
      return (currentP / qty) * 1000;
    } else if (u.contains(' l')) {
      final double qty = double.tryParse(u.split(' ')[0]) ?? 1.0;
      return currentP / qty;
    } else if (u.contains('ml')) {
      final double qty = double.tryParse(u.split(' ')[0]) ?? 500.0;
      return (currentP / qty) * 1000;
    }
    return null;
  }
}

class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String? userImage;
  final double rating;
  final String review;
  final List<String> images;
  final DateTime createdAt;
  final String? ownerReply;
  final bool isFlagged;
  final bool isFeatured;

  ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.rating,
    required this.review,
    this.images = const [],
    required this.createdAt,
    this.ownerReply,
    this.isFlagged = false,
    this.isFeatured = false,
  });

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userImage: map['userImage'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: ProductModel._parseDate(map['createdAt']) ?? DateTime.now(),
      ownerReply: map['ownerReply'],
      isFlagged: map['isFlagged'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'rating': rating,
      'review': review,
      'images': images,
      'createdAt': createdAt,
      'ownerReply': ownerReply,
      'isFlagged': isFlagged,
      'isFeatured': isFeatured,
    };
  }

  String get emoji => '⭐';
}

class CategoryModel {
  final String id;
  final String name;
  final String nameHindi;
  final String icon;
  final String color;
  final int productCount;
  final bool isActive;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.icon,
    required this.color,
    this.productCount = 0,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameHindi: map['nameHindi'] ?? '',
      icon: map['icon'] ?? '',
      color: map['color'] ?? '#FF5722',
      productCount: map['productCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameHindi': nameHindi,
      'icon': icon,
      'color': color,
      'productCount': productCount,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}
