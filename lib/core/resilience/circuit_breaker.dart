import 'dart:async';
import 'package:flutter/foundation.dart';
import '../errors/app_exceptions.dart';

enum CircuitState { closed, open, halfOpen }

class CircuitBreakerConfig {
  final int failureThreshold; // e.g. 5 failures
  final Duration resetTimeout; // e.g. 30 seconds

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
  });
}

/// A generic Circuit Breaker to wrap external service calls (Firebase, Redis, Supabase).
class CircuitBreaker {
  final String serviceName;
  final CircuitBreakerConfig config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;

  CircuitBreaker(this.serviceName, {this.config = const CircuitBreakerConfig()});

  CircuitState get state => _state;
  int get failureCount => _failureCount;

  /// Executes an async task, applying circuit breaker rules
  Future<T> execute<T>(Future<T> Function() task, {FutureOr<T> Function(dynamic)? fallback}) async {
    if (_state == CircuitState.open) {
      if (_lastFailureTime != null && DateTime.now().difference(_lastFailureTime!) > config.resetTimeout) {
        // Transition to half-open to test if the service is back
        _transitionTo(CircuitState.halfOpen);
      } else {
        if (fallback != null) {
          debugPrint('[$serviceName] Circuit OPEN. Executing fallback.');
          return fallback(CircuitBreakerOpenError(serviceName, '$serviceName circuit is currently open'));
        }
        throw CircuitBreakerOpenError(serviceName, '$serviceName circuit is currently open');
      }
    }

    try {
      final result = await task();
      
      if (_state == CircuitState.halfOpen) {
        // Success while half-open -> service recovered
        _transitionTo(CircuitState.closed);
      } else {
        // Success while closed -> reset failure count
        _failureCount = 0;
      }
      
      return result;
    } catch (e, stackTrace) {
      _recordFailure();

      if (fallback != null) {
        debugPrint('[$serviceName] Task failed. Executing fallback. Error: $e');
        return fallback(e);
      }
      
      throw ErrorMapper.map(e, stackTrace);
    }
  }

  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    debugPrint('[$serviceName] Failure recorded. Count: $_failureCount');

    if (_state == CircuitState.halfOpen || _failureCount >= config.failureThreshold) {
      _transitionTo(CircuitState.open);
    }
  }

  void _transitionTo(CircuitState newState) {
    debugPrint('[$serviceName] Circuit transition: ${_state.name} -> ${newState.name}');
    _state = newState;
    if (newState == CircuitState.open) {
      _resetTimer?.cancel();
      _resetTimer = Timer(config.resetTimeout, () {
        debugPrint('[$serviceName] Reset timeout reached. Transitioning to half-open on next request.');
      });
    } else if (newState == CircuitState.closed) {
      _failureCount = 0;
      _resetTimer?.cancel();
    }
  }
}

/// Singleton registry for Circuit Breakers
class CircuitBreakerRegistry {
  static final Map<String, CircuitBreaker> _breakers = {};

  static CircuitBreaker get(String serviceName, {CircuitBreakerConfig? config}) {
    if (!_breakers.containsKey(serviceName)) {
      _breakers[serviceName] = CircuitBreaker(serviceName, config: config ?? const CircuitBreakerConfig());
    }
    return _breakers[serviceName]!;
  }
}
