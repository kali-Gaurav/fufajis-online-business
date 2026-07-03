import React, { useState, useEffect } from 'react';
import { View, FlatList, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { collection, query, getDocs } from 'firebase/firestore';
import { db } from '../services/FirebaseService';
import ProductCard from '../components/ProductCard';
import designTokens from '../constants/designTokens';

/**
 * HomeScreen - Fixed FlatList layout
 * FIX: Proper scrolling, no overflow
 */
const HomeScreen = ({ navigation }) => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        setLoading(true);
        const q = query(collection(db, 'products'));
        const querySnapshot = await getDocs(q);
        const productsData = querySnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));
        setProducts(productsData);
      } catch (error) {
        console.error('Error fetching products:', error);
      } finally {
        setLoading(false);
      }
    };
    fetchProducts();
  }, []);

  const renderProduct = ({ item }) => (
    <ProductCard
      item={item}
      onPress={() => navigation.navigate('ProductDetail', { product: item })}
      onAddToCart={(product) => {
        console.log('Added to cart:', product.id);
      }}
    />
  );

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={styles.greeting}>Good afternoon 👋</Text>
      <Text style={styles.subGreeting}>What can Fufaji pack for you today?</Text>
    </View>
  );

  const renderFooter = () => (
    <View style={styles.footer}>
      {loading && <ActivityIndicator size="large" color={designTokens.colors.accent} />}
      <View style={{ height: designTokens.sizing.bottomNav }} />
    </View>
  );

  if (!loading && products.length === 0) {
    return (
      <View style={styles.emptyContainer}>
        <Text style={styles.emptyTitle}>No products</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={products}
        renderItem={renderProduct}
        keyExtractor={item => item.id}
        numColumns={2}
        columnWrapperStyle={styles.gridRow}
        scrollEnabled={true}
        contentContainerStyle={styles.listContent}
        ListHeaderComponent={renderHeader}
        ListFooterComponent={renderFooter}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: designTokens.colors.background,
  },

  listContent: {
    paddingBottom: designTokens.spacing.lg,
  },

  gridRow: {
    justifyContent: 'space-between',
  },

  header: {
    padding: designTokens.spacing.md,
    backgroundColor: designTokens.colors.surface,
  },

  greeting: {
    fontSize: 20,
    fontWeight: '700',
    color: designTokens.colors.text.primary,
  },

  subGreeting: {
    fontSize: 14,
    color: designTokens.colors.text.secondary,
    marginTop: designTokens.spacing.xs,
  },

  footer: {
    paddingHorizontal: designTokens.spacing.md,
  },

  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },

  emptyTitle: {
    fontSize: 16,
    color: designTokens.colors.text.secondary,
  },
});

export default HomeScreen;
