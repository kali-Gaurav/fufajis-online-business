# Bug Fixes and Project Cleanup

This plan addresses several critical errors and warnings identified in the `fufaji-online-business` project, primarily focusing on missing service references, undefined methods, and unused code.

## User Review Required

> [!IMPORTANT]
> - I've identified that `FirestoreService` is missing, but its functionality (authorizing users, etc.) is present in `UserService`. I will migrate usages of `FirestoreService` to `UserService`.
> - `updateRole` in `AuthProvider` seems to be renamed or replaced by `requestRoleUpdate`. I will update `RoleSelectScreen` to use the correct method.
> - `OrderProvider` was not imported in `qna_section.dart`, causing a "not a type" error.

## Proposed Changes

### Service Layer Migration

Migrate all `FirestoreService` references to `UserService`.

#### [UserService](file:///C:/Projects/fufaji-online-business/lib/services/user_service.dart)

- No changes needed to the file itself, but its methods will be used to replace `FirestoreService`.

#### [khata_screen.dart](file:///C:/Projects/fufaji-online-business/lib/screens/owner/khata_screen.dart)

- Replace `FirestoreService` with `UserService`.
- Fix undefined class error.

#### [rider_management_screen.dart](file:///C:/Projects/fufaji-online-business/lib/screens/owner/rider_management_screen.dart)

- Update import from `../../services/firestore_service.dart` to `../../services/user_service.dart`.
- Replace `FirestoreService` instance with `UserService`.

#### [rider_support_console.dart](file:///C:/Projects/fufaji-online-business/lib/screens/owner/rider_support_console.dart)

- Update import and service usage.

#### [offline_sync_service.dart](file:///C:/Projects/fufaji-online-business/lib/services/offline_sync_service.dart)

- Update import and service usage.

#### [pricing_service.dart](file:///C:/Projects/fufaji-online-business/lib/services/pricing_service.dart)

- Update import and service usage.

---

### Authentication Fixes

#### [role_select_screen.dart](file:///C:/Projects/fufaji-online-business/lib/screens/role_select_screen.dart)

- Update `authProvider.updateRole(role)` to `authProvider.requestRoleUpdate(authProvider.currentUser!.id, role)`.

---

### UI Component Fixes

#### [qna_section.dart](file:///C:/Projects/fufaji-online-business/lib/widgets/qna_section.dart)

- Add missing import: `import '../providers/order_provider.dart';`.

---

### Shorebird Service Fix

#### [shorebird_service.dart](file:///C:/Projects/fufaji-online-business/lib/services/shorebird_service.dart)

- The error `The method 'ShorebirdCodePush' isn't defined` is strange because it's a class. I'll check if it should be `ShorebirdCodePush()` (with parentheses) or if the import is correct.

---

### Warning Cleanup (Priority)

I will also address a few high-impact warnings:
- [main.dart](file:///C:/Projects/fufaji-online-business/lib/main.dart): Remove unused import `services/crash_reporter.dart`.
- [payment_method.dart](file:///C:/Projects/fufaji-online-business/lib/models/payment_method.dart): Fix `non_const_argument_for_const_parameter` if possible.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure all errors and addressed warnings are gone.

### Manual Verification
- I will manually check the files I edit using `analyze_file` to confirm the specific errors are resolved.
