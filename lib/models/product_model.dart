import '../services/logging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

/// Product category enum with localized metadata
enum ProductCategory {
  groceries(nameEn: 'Groceries', nameHi: 'किराना', icon: '🛒', color: '#FF9800'),
  vegetables(nameEn: 'Vegetables', nameHi: 'सब्जियां', icon: '🥦', color: '#4CAF50'),
  fruits(nameEn: 'Fruits', nameHi: 'फल', icon: '🍎', color: '#F44336'),
  dairy(nameEn: 'Dairy', nameHi: 'डेयरी', icon: '🥛', color: '#2196F3'),
  bakery(nameEn: 'Bakery', nameHi: 'बेकरी', icon: '🍞', color: '#795548'),
  snacks(nameEn: 'Snacks', nameHi: 'नमकीन', icon: '🥨', color: '#FF5722'),
  beverages(nameEn: 'Beverages', nameHi: 'पेय पदार्थ', icon: '🥤', color: '#00BCD4'),
  household(nameEn: 'Household', nameHi: 'घर का सामान', icon: '🧹', color: '#607D8B'),
  personalCare(nameEn: 'Personal Care', nameHi: 'पर्सनल केयर', icon: '🧴', color: '#E91E63'),
  electronics(nameEn: 'Electronics', nameHi: 'इलेक्ट्रॉनिक्स', icon: '🔌', color: '#3F51B5'),
  clothing(nameEn: 'Clothing', nameHi: 'कपड़े', icon: '👕', color: '#9C27B0'),
  footwear(nameEn: 'Footwear', nameHi: 'जूते', icon: '👟', color: '#795548'),
  homeDecor(nameEn: 'Home Decor', nameHi: 'सजावट', icon: '🖼️', color: '#FFC107'),
  kitchenware(nameEn: 'Kitchenware', nameHi: 'रसोई का सामान', icon: '🍳', color: '#F44336'),
  stationery(nameEn: 'Stationery', nameHi: 'स्टेशनरी', icon: '✏️', color: '#03A9F4'),
  toys(nameEn: 'Toys', nameHi: 'खिलौने', icon: '🧸', color: '#FF4081'),
  medicines(nameEn: 'Medicines', nameHi: 'दवाइयां', icon: '💊', color: '#F44336'),
  agricultural(nameEn: 'Agricultural', nameHi: 'कृषि उत्पाद', icon: '🚜', color: '#4CAF50'),
  other(nameEn: 'Other', nameHi: 'अन्य', icon: '📦', color: '#9E9E9E');

  final String nameEn;
  final String nameHi;
  final String icon;
  final String color;

  const ProductCategory({
    required this.nameEn,
    required this.nameHi,
    required this.icon,
    required this.color,
  });

  /// Get localized name based on locale string
  String localizedName(String localeCode) {
    return localeCode.startsWith('hi') ? nameHi : nameEn;
  }

  /// Get enum from ID string safely
  static ProductCategory fromId(String? id) {
    if (id == null) return ProductCategory.other;
    final cleanId = id.toLowerCase().trim();
    return ProductCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == cleanId,
      orElse: () => ProductCategory.other,
    );
  }
}

class ProductUnitOption {
  final String id;
  final String name;
  final MonetaryValue price;
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
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: MonetaryValue(map['price'] ?? 0.0),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      stockQuantity: map['stockQuantity'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price.toDouble(),
      'originalPrice': originalPrice,
      'stockQuantity': stockQuantity,
    };
  }
}

class CompetitorPrice {
  final String competitorName;
  final MonetaryValue price;
  final DateTime updatedAt;

  CompetitorPrice({required this.competitorName, required this.price, required this.updatedAt});

  factory CompetitorPrice.fromMap(Map<String, dynamic> map) {
    return CompetitorPrice(
      competitorName: map['competitorName'] as String? ?? '',
      price: MonetaryValue(map['price'] ?? 0.0),
      updatedAt: ProductModel._parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'competitorName': competitorName, 'price': price.toDouble(), 'updatedAt': updatedAt};
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final MonetaryValue price;
  final MonetaryValue? originalPrice;
  final MonetaryValue? discountPercentage;
  final String unit;
  final String categoryId; // Immutable category Id (e.g. 'vegetables')
  final String category; // Legacy/Display name (backward compatibility)
  final String subCategory;
  final String shopId;
  final String shopName;
  final String imageUrl;
  final List<String> images;
  final String hindiName; // NEW: Hindi product name for voice search
  final List<String> keywords; // NEW: Keywords for voice/fuzzy matching (e.g., ["aloo", "potato", "आलू"])
  final double? mrpPrice; // NEW: Maximum Retail Price (separate from selling price)
  final Map<String, String> nutrition; // NEW: Nutrition facts (e.g., {"protein": "12g", "fiber": "8g"})
  final double rating;
  final int reviewCount;
  final int stockQuantity; // Legacy total stock
  final int availableStock; // Phase B: Available for checkout
  final int reservedStock; // Phase B: In checkout / pending payment
  final int soldStock; // Phase B: Completed orders
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
  final Map<String, int> branchStock; // Legacy branch stock
  final Map<String, Map<String, dynamic>> branchStockMap; // Phase B: {branchId: {available, reserved, sold}}
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
    required this.categoryId,
    this.category = '',
    this.subCategory = '',
    required this.shopId,
    required this.shopName,
    required this.imageUrl,
    this.images = const [],
    this.hindiName = '', // NEW: Hindi name default
    this.keywords = const [], // NEW: Keywords default
    this.mrpPrice, // NEW: MRP optional
    this.nutrition = const {}, // NEW: Nutrition default
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.stockQuantity,
    this.availableStock = 0,
    this.reservedStock = 0,
    this.soldStock = 0,
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
    this.branchStockMap = const {},
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
    } catch (e, stack) {
      LoggingService().error('Silent error caught', e, stack);
    }
    return null;
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: MonetaryValue(map['price'] ?? 0.0),
      originalPrice: map['originalPrice'] != null ? MonetaryValue(map['originalPrice']) : null,
      discountPercentage: map['discountPercentage'] != null
          ? MonetaryValue(map['discountPercentage'])
          : null,
      unit: map['unit'] as String? ?? 'piece',
      categoryId: (map['categoryId'] as String?) ?? (map['category'] as String?) ?? 'other',
      category: map['category'] as String? ?? 'other',
      subCategory: map['subCategory'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      images: List<String>.from(map['images'] as Iterable? ?? []),
      hindiName: map['hindiName'] as String? ?? '', // NEW
      keywords: List<String>.from(map['keywords'] as Iterable? ?? []), // NEW
      mrpPrice: (map['mrpPrice'] as num?)?.toDouble(), // NEW
      nutrition: Map<String, String>.from(map['nutrition'] as Map? ?? {}), // NEW
      rating: (map['rating'] as num? ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] as int? ?? 0,
      stockQuantity: map['stockQuantity'] as int? ?? 0,
      availableStock: map['availableStock'] as int? ?? (map['stockQuantity'] as int? ?? 0),
      reservedStock: map['reservedStock'] as int? ?? 0,
      soldStock: map['soldStock'] as int? ?? 0,
      minimumStock: map['minimumStock'] as int? ?? 10,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isFeatured: map['isFeatured'] as bool? ?? false,
      isOnSale: map['isOnSale'] as bool? ?? false,
      isNewArrival: map['isNewArrival'] as bool? ?? false,
      isTrending: map['isTrending'] as bool? ?? false,
      specifications: Map<String, dynamic>.from(map['specifications'] as Map? ?? {}),
      tags: List<String>.from(map['tags'] as Iterable? ?? []),
      barcode: map['barcode'] as String? ?? '',
      brand: map['brand'] as String?,
      origin: map['origin'] as String?,
      expiryDate: _parseDate(map['expiryDate']),
      isExpired: map['isExpired'] as bool? ?? false,
      competitorPrices:
          (map['competitorPrices'] as List?)
              ?.map((x) => CompetitorPrice.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList() ??
          const [],
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      pricingStrategy: map['pricingStrategy'] as String?,
      lastPriceUpdate: _parseDate(map['lastPriceUpdate']),
      weight: (map['weight'] as num?)?.toDouble(),
      weightUnit: map['weightUnit'] as String? ?? 'kg',
      minOrderQuantity: map['minOrderQuantity'] as int? ?? 1,
      maxOrderQuantity: map['maxOrderQuantity'] as int? ?? 100,
      district: map['district'] as String? ?? '',
      village: map['village'] as String? ?? '',
      sourceLocation: map['sourceLocation'] as GeoPoint?,
      sourceName: map['sourceName'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      unitOptions:
          (map['unitOptions'] as List?)
              ?.map((x) => ProductUnitOption.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList() ??
          const [],
      lightningDealPrice: (map['lightningDealPrice'] as num?)?.toDouble(),
      lightningDealEndTime: _parseDate(map['lightningDealEndTime']),
      farmStory: map['farmStory'] as String?,
      farmerName: map['farmerName'] as String?,
      farmerImageUrl: map['farmerImageUrl'] as String?,
      harvestDate: _parseDate(map['harvestDate']),
      isOrganicCertified: map['isOrganicCertified'] as bool? ?? false,
      branchStock:
          (map['branchStock'] as Map?)?.map((k, v) => MapEntry(k.toString(), v as int)) ?? const {},
      branchStockMap: Map<String, Map<String, dynamic>>.from(map['branchStockMap'] as Map? ?? {}),
      branchLocations:
          (map['branchLocations'] as Map?)?.map((k, v) {
            if (v is Map) {
              return MapEntry(k.toString(), Map<String, dynamic>.from(v));
            } else if (v is String) {
              final regAisle = RegExp(r'Aisle\s+([A-Za-z0-9]+)', caseSensitive: false);
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
      shelfPhotoUrl: map['shelfPhotoUrl'] as String?,
      shelfPhotoUpdatedAt: _parseDate(map['shelfPhotoUpdatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price.toDouble(),
      'originalPrice': originalPrice?.toDouble(),
      'discountPercentage': discountPercentage?.toDouble(),
      'unit': unit,
      'categoryId': categoryId,
      'category': category,
      'subCategory': subCategory,
      'shopId': shopId,
      'shopName': shopName,
      'imageUrl': imageUrl,
      'images': images,
      'hindiName': hindiName, // NEW
      'keywords': keywords, // NEW
      'mrpPrice': mrpPrice?.toDouble(), // NEW
      'nutrition': nutrition, // NEW
      'rating': rating,
      'reviewCount': reviewCount,
      'stockQuantity': stockQuantity,
      'availableStock': availableStock,
      'reservedStock': reservedStock,
      'soldStock': soldStock,
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
      'costPrice': costPrice?.toDouble(),
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
      'lightningDealPrice': lightningDealPrice?.toDouble(),
      'lightningDealEndTime': lightningDealEndTime?.toIso8601String(),
      'farmStory': farmStory,
      'farmerName': farmerName,
      'farmerImageUrl': farmerImageUrl,
      'harvestDate': harvestDate?.toIso8601String(),
      'isOrganicCertified': isOrganicCertified,
      'branchStock': branchStock,
      'branchStockMap': branchStockMap,
      'branchLocations': branchLocations,
      'shelfPhotoUrl': shelfPhotoUrl,
      'shelfPhotoUpdatedAt': shelfPhotoUpdatedAt?.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    MonetaryValue? price,
    MonetaryValue? originalPrice,
    MonetaryValue? discountPercentage,
    String? unit,
    String? categoryId,
    String? category,
    String? subCategory,
    String? shopId,
    String? shopName,
    String? imageUrl,
    List<String>? images,
    String? hindiName, // NEW
    List<String>? keywords, // NEW
    double? mrpPrice, // NEW
    Map<String, String>? nutrition, // NEW
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
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      hindiName: hindiName ?? this.hindiName, // NEW
      keywords: keywords ?? this.keywords, // NEW
      mrpPrice: mrpPrice ?? this.mrpPrice, // NEW
      nutrition: nutrition ?? this.nutrition, // NEW
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

  MonetaryValue get currentPrice {
    if (isLightningDealActive) {
      return MonetaryValue(lightningDealPrice!);
    }
    return price;
  }

  MonetaryValue get discountedPrice {
    if (isLightningDealActive) return MonetaryValue(lightningDealPrice!);
    if (originalPrice != null && originalPrice! > price) {
      return price;
    }
    return price;
  }

  double? get mrp => isLightningDealActive
      ? (originalPrice?.toDouble() ?? price.toDouble())
      : originalPrice?.toDouble();

  double get effectiveDiscount {
    if (isLightningDealActive) {
      final basePrice = originalPrice?.toDouble() ?? price.toDouble();
      if (basePrice <= lightningDealPrice!) return 0;
      return ((basePrice - lightningDealPrice!) / basePrice) * 100;
    }
    if (discountPercentage != null) return discountPercentage!.toDouble();
    if (originalPrice == null || originalPrice! <= price) return 0;
    return ((originalPrice!.toDouble() - price.toDouble()) / originalPrice!.toDouble()) * 100;
  }

  bool get isLocal => village.isNotEmpty || origin?.toLowerCase() == 'local';

  bool get inStock => stockQuantity > 0;

  /// Normalizes price to 1kg/1L for value comparison (Step 13.3)
  double? get normalizedPricePerKg {
    final double currentP = currentPrice.toDouble();
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
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userImage: map['userImage'] as String?,
      rating: (map['rating'] as num? ?? 0.0).toDouble(),
      review: map['review'] as String? ?? '',
      images: List<String>.from(map['images'] as Iterable? ?? []),
      createdAt: ProductModel._parseDate(map['createdAt']) ?? DateTime.now(),
      ownerReply: map['ownerReply'] as String?,
      isFlagged: map['isFlagged'] as bool? ?? false,
      isFeatured: map['isFeatured'] as bool? ?? false,
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
  final String id; // Logic ID
  final String name; // English Name
  final String nameHindi; // Hindi Name
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

  /// Factory from enum for type safety
  factory CategoryModel.fromEnum(ProductCategory cat, {int count = 0}) {
    return CategoryModel(
      id: cat.name,
      name: cat.nameEn,
      nameHindi: cat.nameHi,
      icon: cat.icon,
      color: cat.color,
      productCount: count,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      nameHindi: map['nameHindi'] as String? ?? '',
      icon: map['icon'] as String? ?? '',
      color: map['color'] as String? ?? '#FF5722',
      productCount: map['productCount'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      sortOrder: map['sortOrder'] as int? ?? 0,
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

  /// Get localized label
  String localizedName(String localeCode) {
    return localeCode.startsWith('hi') ? nameHindi : name;
  }
}
