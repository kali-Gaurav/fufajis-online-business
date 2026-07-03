import React, { useState } from 'react';
import { View, Image, Text, Pressable, StyleSheet } from 'react-native';
import designTokens from '../constants/designTokens';

/**
 * ProductCard - Fixed layout (no overflow)
 * FIX: Proper flex sizing, dynamic heights
 */
const ProductCard = ({ item, onAddToCart, onPress }) => {
  const [isPressed, setIsPressed] = useState(false);

  const handleAddToCart = () => {
    setIsPressed(true);
    onAddToCart?.(item);
    setTimeout(() => setIsPressed(false), 300);
  };

  const isOutOfStock = item.stock <= 0;
  const discountPercent = item.discount || 0;

  return (
    <Pressable
      style={[styles.card, isPressed && styles.cardPressed]}
      onPress={() => onPress?.(item)}
    >
      {/* IMAGE */}
      <View style={styles.imageContainer}>
        <Image
          source={{ uri: item.imageUrl || 'https://via.placeholder.com/140' }}
          style={styles.image}
          resizeMode="cover"
        />

        {/* DISCOUNT BADGE */}
        {discountPercent > 0 && (
          <View style={styles.discountBadge}>
            <Text style={styles.discountText}>{discountPercent}% OFF</Text>
          </View>
        )}

        {/* STOCK OVERLAY */}
        {isOutOfStock && (
          <View style={styles.stockOverlay}>
            <Text style={styles.stockText}>Out of Stock</Text>
          </View>
        )}
      </View>

      {/* CONTENT */}
      <View style={styles.content}>
        <Text style={styles.size} numberOfLines={1}>
          {item.size || '1 kg'}
        </Text>

        <View style={styles.priceContainer}>
          <Text style={styles.price}>₹{item.price || 0}</Text>
        </View>

        <Pressable
          style={[styles.addBtn, isOutOfStock && styles.addBtnDisabled]}
          onPress={handleAddToCart}
          disabled={isOutOfStock}
        >
          <Text style={styles.addBtnText}>Add to Cart</Text>
        </Pressable>
      </View>
    </Pressable>
  );
};

const styles = StyleSheet.create({
  card: {
    flex: 1,
    marginHorizontal: designTokens.spacing.sm,
    marginVertical: designTokens.spacing.sm,
    backgroundColor: designTokens.colors.surface,
    borderRadius: designTokens.radius.lg,
    overflow: 'hidden',
    elevation: 2,
  },

  cardPressed: {
    elevation: 4,
  },

  imageContainer: {
    position: 'relative',
    backgroundColor: designTokens.colors.surface2,
    height: designTokens.sizing.productImage,
    width: '100%',
    overflow: 'hidden',
  },

  image: {
    width: '100%',
    height: '100%',
  },

  discountBadge: {
    position: 'absolute',
    top: designTokens.spacing.sm,
    right: designTokens.spacing.sm,
    backgroundColor: designTokens.colors.error,
    paddingHorizontal: designTokens.spacing.sm,
    paddingVertical: 4,
    borderRadius: designTokens.radius.sm,
  },

  discountText: {
    color: designTokens.colors.text.inverse,
    fontSize: 11,
    fontWeight: '700',
  },

  stockOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },

  stockText: {
    color: designTokens.colors.text.inverse,
    fontSize: 12,
    fontWeight: '600',
  },

  content: {
    padding: designTokens.spacing.md,
    flex: 1,
    justifyContent: 'space-between',
  },

  size: {
    fontSize: designTokens.typography.caption.fontSize,
    color: designTokens.colors.text.secondary,
    marginBottom: designTokens.spacing.xs,
  },

  priceContainer: {
    marginVertical: designTokens.spacing.sm,
  },

  price: {
    fontSize: 16,
    fontWeight: '700',
    color: designTokens.colors.primary,
  },

  addBtn: {
    backgroundColor: designTokens.colors.accent,
    paddingVertical: designTokens.spacing.sm,
    borderRadius: designTokens.radius.md,
    alignItems: 'center',
    marginTop: designTokens.spacing.md,
  },

  addBtnDisabled: {
    backgroundColor: designTokens.colors.text.disabled,
    opacity: 0.6,
  },

  addBtnText: {
    color: designTokens.colors.text.inverse,
    fontSize: 12,
    fontWeight: '600',
  },
});

export default ProductCard;
