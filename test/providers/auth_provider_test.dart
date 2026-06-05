import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:fufajis_online/providers/auth_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const codec = StandardMessageCodec();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
      (ByteData? message) async {
        final response = <Object?, Object?>{
          'result': [
            <Object?, Object?>{
              'name': '[DEFAULT]',
              'options': <Object?, Object?>{
                'apiKey': '123',
                'appId': '123',
                'messagingSenderId': '123',
                'projectId': '123',
              },
            }
          ]
        };
        return codec.encodeMessage(response);
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeApp',
      (ByteData? message) async {
        final response = <Object?, Object?>{
          'result': <Object?, Object?>{
            'name': '[DEFAULT]',
            'options': <Object?, Object?>{
              'apiKey': '123',
              'appId': '123',
              'messagingSenderId': '123',
              'projectId': '123',
            },
          }
        };
        return codec.encodeMessage(response);
      },
    );

    // We also need to mock FirebaseAuth and FirebaseFirestore platform channels
    // if we want to test methods that call them.
    // For now, we'll focus on the state and simple logic.
  });

  group('AuthProvider Tests', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider();
    });

    test('Initial state should be logged out', () {
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('Demo login should set current user', () async {
      await authProvider.demoLogin('1234567890', 'Test User');
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.currentUser?.name, 'Test User');
      expect(authProvider.currentUser?.phoneNumber, '1234567890');
    });

    test('OTP generation logic (Email)', () async {
      // Note: This is a side-effect test as it only sets local state in the current implementation
      await authProvider.sendEmailOTP('test@example.com');
      expect(authProvider.isEmailVerification, isTrue);
      expect(authProvider.isLoading, isFalse);
    });
  });
}
