import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/core/resilience/circuit_breaker.dart';
import 'package:fufajis_online/core/errors/app_exceptions.dart';

void main() {
  group('CircuitBreaker Tests', () {
    test('Successful tasks keep circuit closed', () async {
      final breaker = CircuitBreaker(
        'TestService',
        config: const CircuitBreakerConfig(failureThreshold: 3),
      );

      expect(breaker.state, CircuitState.closed);

      final result = await breaker.execute(() async => 'success');
      expect(result, 'success');
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
    });

    test('Consecutive failures open the circuit', () async {
      final breaker = CircuitBreaker(
        'TestService',
        config: const CircuitBreakerConfig(failureThreshold: 3),
      );

      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('Fail $i'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);
      expect(breaker.failureCount, 3);

      // Subsequent call should immediately throw CircuitBreakerOpenError
      expect(() => breaker.execute(() async => 'test'), throwsA(isA<CircuitBreakerOpenError>()));
    });

    test('Fallback is executed when circuit is open', () async {
      final breaker = CircuitBreaker(
        'TestService',
        config: const CircuitBreakerConfig(failureThreshold: 1),
      );

      // Trip the breaker
      try {
        await breaker.execute(() async => throw Exception('Fail'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);

      // Use fallback
      final result = await breaker.execute(() async => 'test', fallback: (e) => 'fallback_data');

      expect(result, 'fallback_data');
    });

    test('Circuit transitions to half-open after timeout', () async {
      // Use a very short timeout for testing
      final breaker = CircuitBreaker(
        'TestService',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          resetTimeout: Duration(milliseconds: 100),
        ),
      );

      try {
        await breaker.execute(() async => throw Exception('Fail'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // The next call will transition it to half-open and try
      final result = await breaker.execute(() async => 'success_after_recovery');

      expect(result, 'success_after_recovery');
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
    });
  });
}
