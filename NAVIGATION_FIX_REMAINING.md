# Remaining Navigation Fixes - Quick Reference

## ✅ Already Fixed (Top 6 Priority Files)
- [x] checkout_screen.dart
- [x] product_detail_screen.dart
- [x] checkout_screen_v2.dart
- [x] support_chat_screen.dart
- [x] owner_chat_detail_screen.dart
- [x] orders_screen.dart

## 📋 Remaining Files to Update (24 files)

### High Priority (Frequent User Interaction)
1. `lib/screens/customer/checkout_screen_new.dart` - Contains pop() calls
2. `lib/screens/owner/order_packing_screen.dart` - Contains pop() calls
3. `lib/screens/owner/shop_location_picker_screen.dart` - Contains pop() calls
4. `lib/screens/customer/loyalty_screen.dart` - Contains pop() calls
5. `lib/screens/owner/owner_chat_center_screen.dart` - Contains pop() calls

### Medium Priority
6. `lib/screens/delivery/delivery_detail_screen.dart`
7. `lib/screens/customer/cart_screen.dart`
8. `lib/screens/customer/search_screen.dart`
9. `lib/screens/security_pin_screen.dart`
10. `lib/screens/auth/verification_wall_screen.dart`

### Lower Priority (Admin/Employee Specific)
11. `lib/screens/auth/access_denied_screen.dart`
12. `lib/screens/auth/new_device_pending_screen.dart`
13. `lib/screens/owner/add_product_screen.dart`
14. `lib/screens/owner/delivery_zones_screen.dart`
15. `lib/screens/owner/branch_management_screen.dart`
16. `lib/screens/owner/supplier_bill_scanner_screen.dart`
17. `lib/screens/owner/bill_scanner_screen.dart`
18. `lib/screens/owner/inventory_receiving_screen.dart`
19. `lib/screens/owner/voice_product_add_screen.dart`
20. `lib/screens/employee/employee_chat_screen.dart`
21. `lib/widgets/error_boundary.dart`
22. `lib/widgets/voice_command_sheet.dart`
23. `lib/widgets/voice_command_fab.dart`
24. `lib/widgets/qna_section.dart`

## How to Fix Remaining Files (DIY)

For each file:

1. **Add imports** at the top:
```dart
import 'package:go_router/go_router.dart';
import '../../utils/navigation_helper.dart';
```

2. **Replace patterns**:
   - `context.pop()` → `NavigationHelper.safePop(context)`
   - `Navigator.of(context).pop()` → `NavigationHelper.safePop(context)`
   - `Navigator.pop(context)` → `NavigationHelper.safePop(context)`
   - `Navigator.pop(context, value)` → `NavigationHelper.safePopWithResult(context, value)`

## Automated Fix Command

If you want to batch update all remaining files using find & replace:

### Option 1: VS Code Global Find & Replace
1. Open Find & Replace (Ctrl+H / Cmd+H)
2. Find: `Navigator\.pop\(context(?:,\s*([^)]*))?\)`
3. Replace: `NavigationHelper.safePop$1(context)`
4. Click "Replace All"

### Option 2: Script-based approach
```bash
# Add imports to all dart files in screens/
for file in lib/screens/**/*.dart; do
  if ! grep -q "navigation_helper" "$file"; then
    sed -i "s/import '..\/..\/utils\/app_theme.dart';/import '..\/..\/utils\/app_theme.dart';\nimport '..\/..\/utils\/navigation_helper.dart';/" "$file"
  fi
done

# Replace all pop() calls
find lib/screens -name "*.dart" -exec sed -i \
  -e 's/context\.pop()/NavigationHelper.safePop(context)/g' \
  -e 's/Navigator\.of(context)\.pop()/NavigationHelper.safePop(context)/g' \
  -e 's/Navigator\.pop(context)/NavigationHelper.safePop(context)/g' \
  {} \;
```

## Priority Recommendation

- **Test now** with the 6 fixed priority files
- **Fix High Priority (5 files)** next based on testing results
- **Batch fix remaining (19 files)** after confirming no issues

## Testing Checklist After Each Batch

- [ ] Can pop from all screens
- [ ] Doesn't crash when popping from root
- [ ] Back button works on all screens
- [ ] No "There is nothing to pop" errors
- [ ] Navigation feels smooth

---

**Status**: 13 critical calls fixed | 37 remaining calls identified
