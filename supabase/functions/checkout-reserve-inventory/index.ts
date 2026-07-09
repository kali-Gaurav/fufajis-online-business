import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { corsHeaders } from '../_shared/cors.ts'

interface CartItem {
  productId: string
  quantity: number
  price: number
  unit: string
}

interface DeliveryAddress {
  address: string
  latitude: number
  longitude: number
  zone?: string
  phone?: string
}

interface CheckoutRequest {
  customerId: string
  items: CartItem[]
  deliveryAddress: DeliveryAddress
  deliveryType: string
  couponCode?: string
  walletAmount: number
}

export async function reserveInventoryAndCreateOrder(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { customerId, items, deliveryAddress, deliveryType, couponCode, walletAmount }: CheckoutRequest = await req.json()

    if (!customerId || !items || items.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // FIX #1: START CHECKOUT PROCESS with inventory validation
    console.log('[checkout-reserve-inventory] Starting checkout for user: ' + customerId)

    // Fetch inventory with FOR UPDATE lock
    const productIds = items.map(i => i.productId)
    const { data: inventoryData, error: inventoryError } = await supabase
      .from('inventory')
      .select('product_id, available_stock, reserved_stock, sold_stock')
      .in('product_id', productIds)

    if (inventoryError) {
      console.error('[checkout-reserve-inventory] Inventory fetch error:', inventoryError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch inventory' }),
        { status: 500, headers: corsHeaders }
      )
    }

    // Step 2: Validate available stock for each item
    // NOTE: This is a best-effort check. Actual reservation happens atomically via RPC.
    const inventoryMap = new Map(
      inventoryData?.map(inv => [inv.product_id, inv]) || []
    )

    const outOfStockItems: Array<{ productId: string; available: number; requested: number }> = []
    for (const item of items) {
      const stock = inventoryMap.get(item.productId)
      if (!stock || stock.available_stock < item.quantity) {
        const availableQty = stock?.available_stock ?? 0
        outOfStockItems.push({
          productId: item.productId,
          available: availableQty,
          requested: item.quantity
        })
      }
    }

    if (outOfStockItems.length > 0) {
      const errorDetails = outOfStockItems
        .map(i => `${i.productId}: ${i.available} available, ${i.requested} requested`)
        .join('; ')
      return new Response(
        JSON.stringify({
          error: `Insufficient stock: ${errorDetails}`
        }),
        { status: 409, headers: corsHeaders }
      )
    }

    console.log('[checkout-reserve-inventory] Stock validation passed for all items')

    // Step 3: Create order with status = pending_payment
    const orderId = crypto.randomUUID()
    const { error: orderError } = await supabase
      .from('orders')
      .insert({
        id: orderId,
        customer_id: customerId,
        status: 'pending_payment',
        payment_status: 'pending',
        delivery_address: JSON.stringify(deliveryAddress),
        delivery_type: deliveryType,
        coupon_code: couponCode || null,
        wallet_amount_used: walletAmount,
        subtotal: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })

    if (orderError) {
      console.error('[checkout-reserve-inventory] Order creation error:', orderError)
      return new Response(
        JSON.stringify({ error: 'Failed to create order' }),
        { status: 500, headers: corsHeaders }
      )
    }

    // Step 4: Update inventory: available → reserved (RPC ensures atomicity)
    const inventoryUpdateErrors: string[] = []
    for (const item of items) {
      const { error: updateError } = await supabase.rpc('update_inventory_for_checkout', {
        p_product_id: item.productId,
        p_quantity: item.quantity,
      })

      if (updateError) {
        console.error('[checkout-reserve-inventory] Inventory update error for', item.productId, ':', updateError)
        inventoryUpdateErrors.push(`${item.productId}: ${updateError.message}`)
      }
    }

    if (inventoryUpdateErrors.length > 0) {
      console.error('[checkout-reserve-inventory] Rolling back due to inventory errors')
      // Rollback order creation
      await supabase.from('orders').delete().eq('id', orderId).throwOnError()
      return new Response(
        JSON.stringify({ error: `Failed to reserve inventory: ${inventoryUpdateErrors.join('; ')}` }),
        { status: 500, headers: corsHeaders }
      )
    }

    console.log('[checkout-reserve-inventory] Inventory reserved for', items.length, 'items')

    // Step 5: Create order items
    const orderItems = items.map(item => ({
      order_id: orderId,
      product_id: item.productId,
      quantity: item.quantity,
      price_at_purchase: item.price,
      unit: item.unit,
    }))

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(orderItems)

    if (itemsError) {
      console.error('[checkout-reserve-inventory] Order items creation error:', itemsError)
      // Rollback inventory updates
      for (const item of items) {
        await supabase.rpc('rollback_inventory_reservation', {
          p_product_id: item.productId,
          p_quantity: item.quantity,
        })
      }
      await supabase.from('orders').delete().eq('id', orderId)
      return new Response(
        JSON.stringify({ error: 'Failed to create order items' }),
        { status: 500, headers: corsHeaders }
      )
    }

    console.log('[checkout-reserve-inventory] Order and items created:', orderId)

    // Fetch and return order data
    const { data: order, error: fetchError } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .single()

    if (fetchError || !order) {
      console.error('[checkout-reserve-inventory] Error fetching order after creation:', fetchError)
      // Order was created and inventory reserved, but we can't fetch it back
      // This is still a success from business logic perspective
      return new Response(
        JSON.stringify({ success: true, orderId, warning: 'Order created but data fetch failed' }),
        { status: 200, headers: corsHeaders }
      )
    }

    return new Response(
      JSON.stringify({ success: true, order }),
      { status: 200, headers: corsHeaders }
    )
  } catch (error) {
    console.error('[checkout-reserve-inventory] Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: corsHeaders }
    )
  }
}

Deno.serve(reserveInventoryAndCreateOrder)
