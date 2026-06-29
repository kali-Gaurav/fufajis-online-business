# Supabase Quick Start Guide

## 5-Minute Setup

### 1. Install Supabase CLI
```bash
npm install -g supabase
# or
brew install supabase/tap/supabase
```

### 2. Link to Supabase Project
```bash
cd fufaji-online-business
supabase projects list
supabase link --project-ref orfikmmpbboesbxdiwzb
```

### 3. Start Local Development
```bash
supabase start
```

This starts:
- PostgreSQL database (port 54322)
- REST API (port 54321)
- GraphQL API (port 54321)
- Realtime (WebSocket)
- Supabase Studio (http://localhost:54323)

### 4. Run Migrations
```bash
supabase migration up
```

Applies all migrations in `supabase/migrations/` directory.

### 5. Configure Environment

**Frontend (.env):**
```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<local-anon-key>
```

**Backend (backend/.env):**
```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SERVICE_ROLE_KEY=<local-service-role-key>
```

Keys are printed when `supabase start` completes.

---

## Common Commands

### Database

```bash
# Push local changes to cloud
supabase db push

# Pull cloud schema to local
supabase db pull

# Reset local database
supabase db reset

# View database
supabase studio

# Run migrations
supabase migration up
```

### Migrations

```bash
# Create new migration
supabase migration new create_users_table

# List migrations
supabase migration list

# Undo migration
supabase migration down
```

### Testing

```bash
# Run tests
supabase test

# View logs
supabase logs --tail
```

### Deployment

```bash
# Deploy to production
supabase db push --linked

# Check status
supabase status
```

---

## Dart Integration

### Install Package

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### Initialize in main.dart

```dart
import 'package:fufaji_store/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(MyApp());
}
```

### Use in Widgets

```dart
import 'package:fufaji_store/services/supabase_service.dart';

class OrderScreen extends StatelessWidget {
  final supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supabaseService.streamCustomerOrders(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final orders = snapshot.data as List;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('Order ${order['order_number']}'),
                subtitle: Text('Status: ${order['status']}'),
              );
            },
          );
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

---

## Node.js Integration

### Install Package

```bash
npm install @supabase/supabase-js
```

### Use in Routes

```javascript
const orderService = require('../services/SupabaseOrderService');

router.post('/orders', async (req, res) => {
  try {
    const order = await orderService.createOrder({
      customerId: req.user.id,
      shopId: req.body.shopId,
      items: req.body.items,
      subtotal: req.body.subtotal,
      total: req.body.total,
    });
    res.json({ success: true, order });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/orders/:id', async (req, res) => {
  try {
    const order = await orderService.getOrder(req.params.id);
    res.json(order);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
```

---

## Database Schema

### Quick Overview

```
users (auth.users)
├── profile data
├── wallet_balance
└── loyalty_points

shops
├── products
│   ├── inventory
│   └── reviews
├── orders
│   ├── items (jsonb)
│   ├── payments
│   └── delivery_tasks
└── coupons

Chats
└── messages

Loyalty
├── loyalty_accounts
└── loyalty_transactions
```

---

## Security

### RLS Policies

All tables have Row Level Security enabled. Users can only see/edit their own data.

Example policy:
```sql
-- Orders visible to customer and shop owner
create policy "Orders visible to customer and owner"
  on orders for select
  using (
    auth.uid() = customer_id 
    OR auth.uid() = (select owner_id from shops where id = orders.shop_id)
  );
```

### Keys

- **Anon Key**: Used by Flutter app (read/write with RLS)
- **Service Role**: Used by backend only (full access)
- **JWT Secret**: Stored securely, never expose

---

## Real-Time Subscriptions

### Dart

```dart
// Listen to order updates
supabaseService.streamOrderStatus(orderId)
  .listen((order) {
    print('Order: ${order['status']}');
  });

// Listen to messages
supabaseService.streamChatMessages(chatId)
  .listen((messages) {
    setState(() {
      this.messages = messages;
    });
  });
```

### JavaScript

```javascript
// Subscribe to order changes
const subscription = supabaseService.admin
  .from('orders')
  .on('*', payload => {
    console.log('Order changed:', payload);
  })
  .subscribe();

// Listen to messages
const messageSubscription = supabaseService.admin
  .from('messages')
  .on('INSERT', payload => {
    console.log('New message:', payload.new);
  })
  .subscribe();
```

---

## Troubleshooting

### Connection Issues

```bash
# Check Supabase is running
supabase status

# View logs
supabase logs --tail

# Restart
supabase stop
supabase start
```

### RLS Blocking Access

```dart
// Error: "new row violates row-level security policy"
// Solution: Check RLS policies allow the operation
```

### Migration Errors

```bash
# Check migration status
supabase migration list

# View migration
cat supabase/migrations/<number>_<name>.sql

# Reset if needed
supabase db reset
```

---

## Testing

### Unit Test Example

```dart
test('Create order', () async {
  final order = await supabaseService.createOrder(
    customerId: 'test-user',
    shopId: 'test-shop',
    items: [
      {'product_id': 'prod1', 'quantity': 2, 'price': 500}
    ],
    subtotal: 1000,
    total: 1100,
  );
  
  expect(order['status'], 'pending');
  expect(order['total_amount'], 1100);
});
```

### Integration Test

```dart
testWidgets('Order flow', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  
  // Add items to cart
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  
  // Proceed to checkout
  await tester.tap(find.byText('Checkout'));
  await tester.pumpAndSettle();
  
  // Verify order created
  final orders = await supabaseService.getCustomerOrders(userId);
  expect(orders.isNotEmpty, true);
});
```

---

## Performance Tips

1. **Use Indexes** ✅ Already created
2. **Limit Rows** - Use `limit()` in queries
3. **Filter Early** - Use `where()` to reduce data
4. **Batch Operations** - Use batch insert/update
5. **Connection Pooling** - Enable in config.toml
6. **Cache Results** - Use Redis for frequent queries

---

## Deployment

### Staging

```bash
# Link to staging project
supabase link --project-ref staging-ref

# Test migrations
supabase migration up --dry-run

# Deploy
supabase db push
```

### Production

```bash
# Link to production
supabase link --project-ref orfikmmpbboesbxdiwzb

# Verify migrations
supabase migration list

# Deploy with backup
supabase db push --dry-run
supabase db push
```

---

## Resources

- **Docs**: https://supabase.com/docs
- **Dart SDK**: https://pub.dev/packages/supabase_flutter
- **Node.js SDK**: https://github.com/supabase/supabase-js
- **SQL Editor**: http://localhost:54323 (Studio)
- **REST API**: http://localhost:54321 (Auto-generated)
- **GraphQL**: http://localhost:54321/graphql

---

## Support

For issues or questions:
1. Check Supabase docs
2. Review error logs: `supabase logs --tail`
3. Test in Studio: http://localhost:54323
4. Ask in Supabase Discord

---

**Happy building! 🚀**
