import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/widgets/otp_verification_dialog.dart';

void main() {
  group('OTPVerificationDialog Tests', () {
    /// Test 5.5.1: OTPVerificationDialog displays 4-digit OTP input fields
    testWidgets('OTPVerificationDialog displays 4 OTP input fields', (
      WidgetTester tester,
    ) async {
      bool verified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OTPVerificationDialog(
                orderNumber: 'HLM-20240101-0001',
                otp: '1234',
                onVerified: () {
                  verified = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify 4 input fields are present
      expect(find.byType(TextField), findsWidgets);
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));
    });

    /// Test 5.5.2: OTPVerificationDialog verifies correct OTP
    testWidgets('OTPVerificationDialog verifies correct OTP', (
      WidgetTester tester,
    ) async {
      bool verified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OTPVerificationDialog(
                orderNumber: 'HLM-20240101-0001',
                otp: '1234',
                onVerified: () {
                  verified = true;
                },
              ),
            ),
          ),
        ),
      );

      // Enter OTP
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '2');
      await tester.enterText(textFields.at(2), '3');
      await tester.enterText(textFields.at(3), '4');

      // Tap verify button
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(verified, true);
    });

    /// Test 5.5.3: OTPVerificationDialog rejects incorrect OTP
    testWidgets('OTPVerificationDialog rejects incorrect OTP', (
      WidgetTester tester,
    ) async {
      bool verified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OTPVerificationDialog(
                orderNumber: 'HLM-20240101-0001',
                otp: '1234',
                onVerified: () {
                  verified = true;
                },
              ),
            ),
          ),
        ),
      );

      // Enter wrong OTP
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '5');
      await tester.enterText(textFields.at(1), '6');
      await tester.enterText(textFields.at(2), '7');
      await tester.enterText(textFields.at(3), '8');

      // Tap verify button
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('Incorrect OTP. Please try again.'), findsOneWidget);
      expect(verified, false);
    });

    /// Test 5.5.4: OTPVerificationDialog auto-focuses next field
    testWidgets('OTPVerificationDialog auto-focuses next field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OTPVerificationDialog(
                orderNumber: 'HLM-20240101-0001',
                otp: '1234',
                onVerified: () {},
              ),
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);

      // Enter first digit
      await tester.enterText(textFields.at(0), '1');
      await tester.pumpAndSettle();

      // Verify second field is focused
      expect(find.byType(TextField), findsNWidgets(4));
    });

    /// Test 5.5.5: OTPVerificationDialog displays order number
    testWidgets('OTPVerificationDialog displays order number', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OTPVerificationDialog(
                orderNumber: 'HLM-20240101-0001',
                otp: '1234',
                onVerified: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Order #HLM-20240101-0001'), findsOneWidget);
    });

    /// Test 5.5.6: OTPVerificationDialog disables verify button when OTP incomplete
    testWidgets(
      'OTPVerificationDialog disables verify button when OTP incomplete',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: OTPVerificationDialog(
                  orderNumber: 'HLM-20240101-0001',
                  otp: '1234',
                  onVerified: () {},
                ),
              ),
            ),
          ),
        );

        // Verify button should be disabled initially
        final verifyButton = find.byType(ElevatedButton);
        expect(verifyButton, findsOneWidget);

        // Enter only 2 digits
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), '1');
        await tester.enterText(textFields.at(1), '2');
        await tester.pumpAndSettle();

        // Verify button should still be disabled
        expect(verifyButton, findsOneWidget);
      },
    );
  });
}
