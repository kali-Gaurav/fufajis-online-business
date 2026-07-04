const supabaseService = require('../../config/supabase');

/**
 * Inventory Service - Manages stock, reservations, and deductions
 * Ensures accurate stock tracking across all operations
 */
class SupabaseInventoryService {
  /**
   * Get inventory for product
   */
  async getInventory(productId, shopId = null) {
    try {
      const filters = { product_id: productId };
      if (shopId) filters.shop_id = shopId;

      const inventory = await supabaseService.query('inventory', 'select', {
        filters,
      });
      return inventory[0] || null;
    } catch (error) {
      console.error('[Inventory] Get inventory failed:', error.message);
      throw error;
    }
  }

  /**
   * Create inventory record
   */
  async createInventory({
    productId,
    shopId,
    quantityOnHand = 0,
    quantityReserved = 0,
  }) {
    try {
      const inventory = await supabaseService.query('inventory', 'insert', {
        payload: {
          product_id: productId,
          shop_id: shopId,
          quantity_on_hand: quantityOnHand,
          quantity_reserved: quantityReserved,
          last_updated: new Date().toISOString(),
          created_at: new Date().toISOString(),
        },
      });

      console.log(
        `[Inventory] Created inventory for product: ${productId}, qty: ${quantityOnHand}`,
      );
      return inventory[0];
    } catch (error) {
      console.error('[Inventory] Create inventory failed:', error.message);
      throw error;
    }
  }

  /**
   * Reserve stock (for pending orders)
   */
  async reserveStock(productId, shopId, quantity) {
    try {
      if (quantity <= 0) {
        throw new Error('Quantity must be greater than 0');
      }

      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        throw new Error(
          `Inventory not found for product: ${productId}, shop: ${shopId}`,
        );
      }

      const available = inventory.quantity_on_hand - inventory.quantity_reserved;

      if (available < quantity) {
        throw new Error(
          `Insufficient stock. Available: ${available}, Requested: ${quantity}`,
        );
      }

      // Use RPC to handle increment atomically
      await supabaseService.rawQuery('reserve_inventory', {
        p_product_id: productId,
        p_shop_id: shopId,
        p_quantity: quantity,
      });

      console.log(
        `[Inventory] Reserved ${quantity} units of product: ${productId}`,
      );
      return true;
    } catch (error) {
      console.error('[Inventory] Reserve stock failed:', error.message);
      throw error;
    }
  }

  /**
   * Deduct stock (for completed orders)
   */
  async deductStock(productId, shopId, quantity) {
    try {
      if (quantity <= 0) {
        throw new Error('Quantity must be greater than 0');
      }

      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        throw new Error(
          `Inventory not found for product: ${productId}, shop: ${shopId}`,
        );
      }

      if (inventory.quantity_reserved < quantity) {
        throw new Error(
          `Cannot deduct more than reserved. Reserved: ${inventory.quantity_reserved}, Requested: ${quantity}`,
        );
      }

      await supabaseService.query('inventory', 'update', {
        payload: {
          quantity_on_hand: supabaseService.admin.raw(
            `quantity_on_hand - ${quantity}`,
          ),
          quantity_reserved: supabaseService.admin.raw(
            `quantity_reserved - ${quantity}`,
          ),
          last_updated: new Date().toISOString(),
        },
        filters: { product_id: productId, shop_id: shopId },
      });

      // Update product stock status
      const updatedInventory = await this.getInventory(productId, shopId);
      if (updatedInventory.quantity_on_hand === 0) {
        await supabaseService.query('products', 'update', {
          payload: { status: 'out_of_stock', in_stock: false },
          filters: { id: productId },
        });
      }

      console.log(
        `[Inventory] Deducted ${quantity} units of product: ${productId}`,
      );
      return true;
    } catch (error) {
      console.error('[Inventory] Deduct stock failed:', error.message);
      throw error;
    }
  }

  /**
   * Release reserved stock (for cancelled orders)
   */
  async releaseReservedStock(productId, shopId, quantity) {
    try {
      if (quantity <= 0) {
        throw new Error('Quantity must be greater than 0');
      }

      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        throw new Error(
          `Inventory not found for product: ${productId}, shop: ${shopId}`,
        );
      }

      if (inventory.quantity_reserved < quantity) {
        throw new Error(
          `Cannot release more than reserved. Reserved: ${inventory.quantity_reserved}, Requested: ${quantity}`,
        );
      }

      await supabaseService.query('inventory', 'update', {
        payload: {
          quantity_reserved: supabaseService.admin.raw(
            `quantity_reserved - ${quantity}`,
          ),
          last_updated: new Date().toISOString(),
        },
        filters: { product_id: productId, shop_id: shopId },
      });

      console.log(
        `[Inventory] Released ${quantity} reserved units of product: ${productId}`,
      );
      return true;
    } catch (error) {
      console.error('[Inventory] Release reserved stock failed:', error.message);
      throw error;
    }
  }

  /**
   * Add stock (for manual adjustments or returns)
   */
  async addStock(productId, shopId, quantity, reason = null) {
    try {
      if (quantity <= 0) {
        throw new Error('Quantity must be greater than 0');
      }

      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        throw new Error(
          `Inventory not found for product: ${productId}, shop: ${shopId}`,
        );
      }

      await supabaseService.query('inventory', 'update', {
        payload: {
          quantity_on_hand: supabaseService.admin.raw(
            `quantity_on_hand + ${quantity}`,
          ),
          last_updated: new Date().toISOString(),
        },
        filters: { product_id: productId, shop_id: shopId },
      });

      // Update product stock status if needed
      const updatedInventory = await this.getInventory(productId, shopId);
      if (updatedInventory.quantity_on_hand > 0) {
        await supabaseService.query('products', 'update', {
          payload: { status: 'active', in_stock: true },
          filters: { id: productId },
        });
      }

      console.log(
        `[Inventory] Added ${quantity} units of product: ${productId}${reason ? ` (${reason})` : ''}`,
      );
      return true;
    } catch (error) {
      console.error('[Inventory] Add stock failed:', error.message);
      throw error;
    }
  }

  /**
   * Get low stock products
   */
  async getLowStockProducts(shopId, limit = 50) {
    try {
      const allInventory = await supabaseService.query('inventory', 'select', {
        filters: { shop_id: shopId },
      });

      // Get products
      const products = await supabaseService.query('products', 'select', {
        filters: { shop_id: shopId },
      });

      const lowStockProducts = allInventory
        .filter((inv) => {
          const product = products.find((p) => p.id === inv.product_id);
          return (
            product
            && inv.quantity_available
            < (product.low_stock_threshold || 5)
          );
        })
        .slice(0, limit);

      return lowStockProducts;
    } catch (error) {
      console.error('[Inventory] Get low stock products failed:', error.message);
      throw error;
    }
  }

  /**
   * Get inventory summary for shop
   */
  async getInventorySummary(shopId) {
    try {
      const inventory = await supabaseService.query('inventory', 'select', {
        filters: { shop_id: shopId },
      });

      return {
        total_products: inventory.length,
        total_stock_value: inventory.reduce(
          (sum, inv) => sum + (inv.quantity_on_hand || 0),
          0,
        ),
        total_reserved: inventory.reduce(
          (sum, inv) => sum + (inv.quantity_reserved || 0),
          0,
        ),
        total_available: inventory.reduce((sum, inv) => {
          const available = (inv.quantity_on_hand || 0)
            - (inv.quantity_reserved || 0);
          return sum + (available > 0 ? available : 0);
        }, 0),
        low_stock_count: inventory.filter((inv) => (inv.quantity_available || 0) < 5)
          .length,
      };
    } catch (error) {
      console.error('[Inventory] Get summary failed:', error.message);
      throw error;
    }
  }

  /**
   * Check stock availability
   */
  async checkAvailability(productId, shopId, quantity) {
    try {
      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        return false;
      }

      const available = inventory.quantity_on_hand - inventory.quantity_reserved;
      return available >= quantity;
    } catch (error) {
      console.error('[Inventory] Check availability failed:', error.message);
      throw error;
    }
  }

  /**
   * Update stock manually (admin only)
   */
  async updateStockManually(productId, shopId, newQuantity, reason) {
    try {
      const inventory = await this.getInventory(productId, shopId);

      if (!inventory) {
        throw new Error(
          `Inventory not found for product: ${productId}, shop: ${shopId}`,
        );
      }

      const difference = newQuantity - inventory.quantity_on_hand;

      await supabaseService.query('inventory', 'update', {
        payload: {
          quantity_on_hand: newQuantity,
          last_stock_check: new Date().toISOString(),
          last_updated: new Date().toISOString(),
        },
        filters: { product_id: productId, shop_id: shopId },
      });

      console.log(
        `[Inventory] Updated stock for product: ${productId}, difference: ${difference}, reason: ${reason}`,
      );
      return true;
    } catch (error) {
      console.error('[Inventory] Update stock manually failed:', error.message);
      throw error;
    }
  }
}

module.exports = new SupabaseInventoryService();
