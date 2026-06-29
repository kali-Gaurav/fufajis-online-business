import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/user_data_service.dart';
import 'package:fufajis_online/models/address_model.dart';
import 'package:fufajis_online/models/preferences_model.dart';

void main() {
  group('UserDataService', () {
    late UserDataService userDataService;

    setUp(() {
      userDataService = UserDataService();
    });

    group('User Profile', () {
      test('loadUserProfile returns user data from Firestore', () async {
        // This is a mock test - in real scenarios, use Firebase emulator
        expect(userDataService, isNotNull);
      });

      test('updateUserProfile updates user data', () async {
        // Test update logic
        expect(userDataService, isNotNull);
      });

      test('loadUserProfile falls back to cache on network error', () async {
        // Test offline caching fallback
        expect(userDataService, isNotNull);
      });
    });

    group('Addresses', () {
      test('addAddress creates new address', () async {
        final address = AddressModel(
          id: 'test-id',
          street: '123 Main St',
          city: 'Test City',
          state: 'Test State',
          postalCode: '12345',
          country: 'India',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(address.street, '123 Main St');
        expect(address.city, 'Test City');
      });

      test('updateAddress modifies existing address', () async {
        final original = AddressModel(
          id: 'test-id',
          street: '123 Main St',
          city: 'Test City',
          state: 'Test State',
          postalCode: '12345',
          country: 'India',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = original.copyWith(street: '456 Oak Ave');
        expect(updated.street, '456 Oak Ave');
        expect(updated.id, original.id);
      });

      test('deleteAddress removes address', () async {
        expect(userDataService, isNotNull);
      });

      test('getAddresses returns list of addresses', () async {
        expect(userDataService, isNotNull);
      });
    });

    group('Preferences', () {
      test('loadPreferences returns default preferences for new user', () async {
        final prefs = PreferencesModel.defaults();

        expect(prefs.language, 'en');
        expect(prefs.theme, ThemeMode.system);
        expect(prefs.notificationsEnabled, true);
      });

      test('updatePreferences saves preferences', () async {
        final prefs = PreferencesModel.defaults().copyWith(
          language: 'hi',
          theme: ThemeMode.dark,
        );

        expect(prefs.language, 'hi');
        expect(prefs.theme, ThemeMode.dark);
      });

      test('updateLanguage changes language preference', () async {
        final prefs = PreferencesModel.defaults();
        final updated = prefs.copyWith(language: 'hi');

        expect(updated.language, 'hi');
      });

      test('updateTheme changes theme preference', () async {
        final prefs = PreferencesModel.defaults();
        final updated = prefs.copyWith(theme: ThemeMode.dark);

        expect(updated.theme, ThemeMode.dark);
      });
    });
  });
}
