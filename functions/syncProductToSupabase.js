const functions = require('firebase-functions');
const { createClient } = require('@supabase/supabase-js');

/**
 * Upstream Sync: Firestore -> Supabase (Products)
 * Triggers when a product is created, updated, or deleted in Firestore.
 */
exports.syncProductToSupabase = functions.runWith({
    secrets: ['SUPABASE_URL', 'SUPABASE_SECRET_KEY']
}).firestore
    .document('products/{productId}')
    .onWrite(async (change, context) => {
        const productId = context.params.productId;
        
        // Supabase configuration
        const supabaseUrl = process.env.SUPABASE_URL;
        const supabaseKey = process.env.SUPABASE_SECRET_KEY;
        
        if (!supabaseUrl || !supabaseKey) {
            console.error('Missing SUPABASE_URL or SUPABASE_SECRET_KEY');
            return null;
        }

        const supabase = createClient(supabaseUrl, supabaseKey, {
            auth: { persistSession: false }
        });

        // Handle Delete
        if (!change.after.exists) {
            console.log(`Product ${productId} deleted from Firestore. Removing from Supabase.`);
            const { error } = await supabase
                .from('products')
                .delete()
                .eq('id', productId);
            
            if (error) console.error('Error deleting product from Supabase:', error);
            return null;
        }

        // Handle Create / Update
        const data = change.after.data();
        
        // Map Firestore data to PostgreSQL schema
        const productPayload = {
            id: productId, // If the schema expects a different primary key, this needs mapping
            name: data.name,
            hindi_name: data.hindiName,
            category: data.category,
            price: data.price,
            original_price: data.originalPrice || data.mrpPrice || data.price,
            stock: data.stock,
            description: data.description,
            image_url: data.imageUrl,
            updated_at: new Date().toISOString()
        };

        // Remove undefined fields to prevent UPSERT errors
        Object.keys(productPayload).forEach(key => {
            if (productPayload[key] === undefined) {
                delete productPayload[key];
            }
        });

        console.log(`Syncing product ${productId} to Supabase...`);
        const { error } = await supabase
            .from('products')
            .upsert(productPayload);

        if (error) {
            console.error(`Error syncing product ${productId} to Supabase:`, error);
        } else {
            console.log(`Successfully synced product ${productId} to Supabase.`);
        }

        return null;
    });
