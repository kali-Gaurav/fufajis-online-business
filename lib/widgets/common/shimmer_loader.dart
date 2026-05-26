import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  const ShimmerLoader.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  }) : shape = BoxShape.rectangle;

  const ShimmerLoader.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoader.rectangular(
            height: 120,
            borderRadius: 12,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoader.rectangular(height: 16, width: 100),
                const SizedBox(height: 8),
                const ShimmerLoader.rectangular(height: 12, width: 60),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ShimmerLoader.rectangular(height: 20, width: 50),
                    const ShimmerLoader.circular(size: 32),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
