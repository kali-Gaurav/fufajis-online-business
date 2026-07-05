/**
 * Phase H Concurrency Test
 *
 * CRITICAL: Validates that concurrent checkouts with limited stock
 * are handled correctly with zero stock leakage.
 *
 * Test Scenario:
 * - 50 concurrent checkout requests
 * - Limited stock: 10 units
 * - Expected: 10 succeed, 40 fail, 0 stock leakage
 *
 * This verifies PostgreSQL row-level locking and transaction safety.
 */

import { createClient } from "@supabase/supabase-js";

interface CheckoutRequest {
  orderId: string;
  userId: string;
  productId: string;
  quantity: number;
}

interface CheckoutResult {
  success: boolean;
  orderId?: string;
  error?: string;
  reservedStock?: number;
}

class ConcurrencyTestRunner {
  private supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  private readonly TEST_PRODUCT_ID = "test-product-concurrency-001";
  private readonly INITIAL_STOCK = 10;
  private readonly CONCURRENT_REQUESTS = 50;
  private readonly STOCK_PER_ORDER = 1;

  async setup(): Promise<void> {
    console.log("[Setup] Preparing test product...");

    // Clear any previous test data
    await this.supabase
      .from("products")
      .delete()
      .eq("id", this.TEST_PRODUCT_ID);

    // Create test product with 10 available stock
    const { error: insertErr } = await this.supabase
      .from("products")
      .insert({
        id: this.TEST_PRODUCT_ID,
        name: "Test Product - Concurrency",
        description: "For concurrency testing only",
        available_stock: this.INITIAL_STOCK,
        reserved_stock: 0,
        sold_stock: 0,
      });

    if (insertErr) {
      throw new Error(`Setup failed: ${insertErr.message}`);
    }

    console.log(
      `[Setup] ✅ Product created with ${this.INITIAL_STOCK} available stock`
    );
  }

  async runConcurrentCheckouts(): Promise<CheckoutResult[]> {
    console.log(
      `\n[Test] Running ${this.CONCURRENT_REQUESTS} concurrent checkouts...`
    );

    const requests: Promise<CheckoutResult>[] = [];

    for (let i = 0; i < this.CONCURRENT_REQUESTS; i++) {
      const orderId = `order-${Date.now()}-${i}`;
      const userId = `user-${i}`;

      const promise = this.attemptCheckout({
        orderId,
        userId,
        productId: this.TEST_PRODUCT_ID,
        quantity: this.STOCK_PER_ORDER,
      });

      requests.push(promise);
    }

    // Execute all requests concurrently
    const results = await Promise.all(requests);
    return results;
  }

  private async attemptCheckout(
    req: CheckoutRequest
  ): Promise<CheckoutResult> {
    try {
      // Call Supabase Edge Function to process checkout
      const response = await this.supabase.functions.invoke(
        "order-lifecycle",
        {
          body: {
            action: "process-checkout",
            orderId: req.orderId,
            userId: req.userId,
            items: [
              {
                productId: req.productId,
                quantity: req.quantity,
              },
            ],
          },
        }
      );

      if (response.error) {
        return {
          success: false,
          orderId: req.orderId,
          error: response.error.message,
        };
      }

      const data = response.data as any;

      if (data.success === true) {
        return {
          success: true,
          orderId: req.orderId,
          reservedStock: req.quantity,
        };
      }

      return {
        success: false,
        orderId: req.orderId,
        error: data.error || "Unknown error",
      };
    } catch (error) {
      return {
        success: false,
        orderId: req.orderId,
        error: error instanceof Error ? error.message : "Network error",
      };
    }
  }

  async verifyStockIntegrity(): Promise<{
    availableStock: number;
    reservedStock: number;
    soldStock: number;
    totalStock: number;
    isValid: boolean;
  }> {
    const { data: product, error } = await this.supabase
      .from("products")
      .select(
        "available_stock, reserved_stock, sold_stock"
      )
      .eq("id", this.TEST_PRODUCT_ID)
      .single();

    if (error || !product) {
      throw new Error(`Failed to fetch product: ${error?.message}`);
    }

    const availableStock = product.available_stock || 0;
    const reservedStock = product.reserved_stock || 0;
    const soldStock = product.sold_stock || 0;
    const totalStock = availableStock + reservedStock + soldStock;

    // Stock should always sum to INITIAL_STOCK (no leakage)
    const isValid = totalStock === this.INITIAL_STOCK;

    return {
      availableStock,
      reservedStock,
      soldStock,
      totalStock,
      isValid,
    };
  }

  async cleanup(): Promise<void> {
    console.log("\n[Cleanup] Removing test data...");

    // Delete test orders
    await this.supabase
      .from("orders")
      .delete()
      .eq("product_id", this.TEST_PRODUCT_ID);

    // Delete test product
    await this.supabase
      .from("products")
      .delete()
      .eq("id", this.TEST_PRODUCT_ID);

    console.log("[Cleanup] ✅ Test data removed");
  }

  async run(): Promise<void> {
    try {
      // Setup
      await this.setup();

      // Run concurrent checkouts
      const results = await this.runConcurrentCheckouts();

      // Analyze results
      const successful = results.filter((r) => r.success).length;
      const failed = results.filter((r) => !r.success).length;

      console.log("\n[Results] Checkout Outcomes:");
      console.log(`  ✅ Successful: ${successful}`);
      console.log(`  ❌ Failed: ${failed}`);
      console.log(`  Total: ${results.length}`);

      // Verify stock integrity
      const stockStatus = await this.verifyStockIntegrity();

      console.log("\n[Results] Stock Integrity:");
      console.log(`  Available: ${stockStatus.availableStock}`);
      console.log(`  Reserved: ${stockStatus.reservedStock}`);
      console.log(`  Sold: ${stockStatus.soldStock}`);
      console.log(`  Total: ${stockStatus.totalStock} (should be ${this.INITIAL_STOCK})`);

      // Verdict
      console.log("\n[Verdict]");
      const expectedSuccessful = this.INITIAL_STOCK;
      const expectedFailed = this.CONCURRENT_REQUESTS - expectedSuccessful;

      const passSuccessful = successful === expectedSuccessful;
      const passFailed = failed === expectedFailed;
      const passIntegrity = stockStatus.isValid;

      console.log(
        `  ${passSuccessful ? "✅" : "❌"} Successful checkouts: ${successful} (expected ${expectedSuccessful})`
      );
      console.log(
        `  ${passFailed ? "✅" : "❌"} Failed checkouts: ${failed} (expected ${expectedFailed})`
      );
      console.log(
        `  ${passIntegrity ? "✅" : "❌"} Stock leakage: ${stockStatus.isValid ? "NONE (Pass)" : "DETECTED (Fail)"}`
      );

      if (passSuccessful && passFailed && passIntegrity) {
        console.log("\n🎉 CONCURRENCY TEST PASSED");
        process.exit(0);
      } else {
        console.log("\n❌ CONCURRENCY TEST FAILED");
        process.exit(1);
      }
    } catch (error) {
      console.error("[Fatal Error]", error);
      process.exit(1);
    } finally {
      await this.cleanup();
    }
  }
}

// Run the test
const runner = new ConcurrencyTestRunner();
runner.run();
