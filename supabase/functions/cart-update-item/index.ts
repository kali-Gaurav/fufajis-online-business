import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { corsHeaders } from '../_shared/cors.ts'

interface CartUpdateRequest {
  itemId: string
  quantity: number
  requestVersion: number
}

export async function updateCartItem(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { itemId, quantity, requestVersion }: CartUpdateRequest = await req.json()

    if (!itemId || quantity === undefined || requestVersion === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // FIX #2: Check request idempotency via cart_request_log
    console.log('[cart-update-item] Checking idempotency for item: ' + itemId + ' version: ' + requestVersion)

    const { data: existingLog, error: logError } = await supabase
      .from('cart_request_log')
      .select('id')
      .eq('item_id', itemId)
      .eq('request_version', requestVersion)
      .limit(1)
      .maybeSingle()

    // If this request was already processed, return success (idempotency)
    if (existingLog) {
      console.log('[cart-update-item] Request already processed (duplicate), returning success')
      return new Response(
        JSON.stringify({ success: true, duplicate: true }),
        { status: 200, headers: corsHeaders }
      )
    }

    if (logError) {
      console.error('[cart-update-item] Log fetch error:', logError)
      // Continue anyway - idempotency check is best-effort
    }

    console.log('[cart-update-item] Processing request for item: ' + itemId + ' qty: ' + quantity)

    // Step 1: Update cart item quantity
    if (quantity > 0) {
      const { error: updateError } = await supabase
        .from('cart_items')
        .update({
          quantity: quantity,
          updated_at: new Date().toISOString(),
        })
        .eq('id', itemId)

      if (updateError) {
        console.error('[cart-update-item] Update error:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to update cart item' }),
          { status: 500, headers: corsHeaders }
        )
      }
    } else {
      // Remove item if quantity <= 0
      const { error: deleteError } = await supabase
        .from('cart_items')
        .delete()
        .eq('id', itemId)

      if (deleteError) {
        console.error('[cart-update-item] Delete error:', deleteError)
        return new Response(
          JSON.stringify({ error: 'Failed to delete cart item' }),
          { status: 500, headers: corsHeaders }
        )
      }
    }

    // Step 2: Log request for idempotency
    const { error: logInsertError } = await supabase
      .from('cart_request_log')
      .insert({
        item_id: itemId,
        request_version: requestVersion,
        processed_at: new Date().toISOString(),
      })

    if (logInsertError) {
      console.error('[cart-update-item] Failed to log request:', logInsertError)
      // Don't fail the entire request if logging fails, but log the error
    }

    console.log('[cart-update-item] Successfully updated item: ' + itemId)

    return new Response(
      JSON.stringify({ success: true, duplicate: false }),
      { status: 200, headers: corsHeaders }
    )
  } catch (error) {
    console.error('[cart-update-item] Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: corsHeaders }
    )
  }
}

Deno.serve(updateCartItem)
