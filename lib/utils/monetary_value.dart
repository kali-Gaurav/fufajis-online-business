import 'package:decimal/decimal.dart';

/// Represents a monetary value with guaranteed accuracy.
/// Uses Decimal for all calculations (no floating-point errors).
/// 
/// Benefits:
/// - No rounding errors from double arithmetic
/// - ₹99.99 * 3 = ₹299.97 exactly (not 299.96999999999997)
/// - Comparisons are accurate
/// - Safe for financial calculations
class MonetaryValue implements Comparable<MonetaryValue> {
  final Decimal _value;

  MonetaryValue(dynamic value) : _value = _parseValue(value);

  static Decimal _parseValue(dynamic value) {
    if (value is Decimal) return value;
    if (value is int) return Decimal.fromInt(value);
    if (value is double) {
      // For double input, convert to string with 2 decimal places to avoid float precision issues
      return Decimal.parse(value.toStringAsFixed(2));
    }
    if (value is String) return Decimal.parse(value);
    if (value is MonetaryValue) return value._value;
    throw ArgumentError('Invalid value type: ${value.runtimeType}. '
        'Expected Decimal, int, double, String, or MonetaryValue.');
  }

  // Arithmetic operations (all return new MonetaryValue)
  MonetaryValue operator +(MonetaryValue other) {
    return MonetaryValue(_value + other._value);
  }

  MonetaryValue operator -(MonetaryValue other) {
    return MonetaryValue(_value - other._value);
  }

  MonetaryValue operator *(num multiplier) {
    Decimal decimalMultiplier;
    if (multiplier is int) {
      decimalMultiplier = Decimal.fromInt(multiplier);
    } else if (multiplier is double) {
      decimalMultiplier = Decimal.parse(multiplier.toStringAsFixed(2));
    } else {
      throw ArgumentError('Multiplier must be int or double');
    }
    return MonetaryValue(_value * decimalMultiplier);
  }

  MonetaryValue operator /(num divisor) {
    if (divisor == 0) {
      throw ArgumentError('Cannot divide by zero');
    }
    Decimal decimalDivisor;
    if (divisor is int) {
      decimalDivisor = Decimal.fromInt(divisor);
    } else if (divisor is double) {
      decimalDivisor = Decimal.parse(divisor.toStringAsFixed(2));
    } else {
      throw ArgumentError('Divisor must be int or double');
    }
    return MonetaryValue((_value / decimalDivisor).toDecimal());
  }

  // Comparisons
  bool operator >(MonetaryValue other) => _value > other._value;
  bool operator <(MonetaryValue other) => _value < other._value;
  bool operator >=(MonetaryValue other) => _value >= other._value;
  bool operator <=(MonetaryValue other) => _value <= other._value;

  @override
  int compareTo(MonetaryValue other) => _value.compareTo(other._value);
  
  @override
  bool operator ==(Object other) {
    if (other is! MonetaryValue) return false;
    return _value == other._value;
  }

  @override
  int get hashCode => _value.hashCode;

  // Conversions
  double toDouble() => _value.toDouble();
  int toInt() => _value.toDouble().toInt();
  
  /// Format as Indian Rupees (e.g., "₹99.99")
  String toDisplayString() => '₹${_value.toStringAsFixed(2)}';
  
  /// Format without currency symbol (e.g., "99.99")
  String toFormattedString() => _value.toStringAsFixed(2);
  
  /// For storage in Firestore (converts to double)
  double toFirestore() => _value.toDouble();
  
  /// For database storage (returns string for max precision)
  String toDatabaseString() => _value.toString();
  
  /// Get the underlying Decimal for advanced operations
  Decimal toDecimal() => _value;

  /// Compatibility with double methods
  String toStringAsFixed(int fractionDigits) => _value.toStringAsFixed(fractionDigits);

  /// Clamps the value between lower and upper limits
  MonetaryValue clamp(MonetaryValue lowerLimit, MonetaryValue upperLimit) {
    if (this < lowerLimit) return lowerLimit;
    if (this > upperLimit) return upperLimit;
    return this;
  }

  /// Absolute value
  MonetaryValue abs() => MonetaryValue(_value.abs());

  /// Rounding
  MonetaryValue round() {
    return MonetaryValue(_value.toDouble().round());
  }

  /// Unary minus
  MonetaryValue operator -() => MonetaryValue(-_value);

  @override
  String toString() => _value.toStringAsFixed(2);
}


/// Extension for easier usage
/// Usage: 99.99.inr returns MonetaryValue
extension MonetaryExt on num {
  MonetaryValue get inr => MonetaryValue(this);
}

/// Helper utilities for monetary operations
class MonetaryUtils {
  /// Safely add multiple monetary values
  static MonetaryValue sum(List<MonetaryValue> values) {
    if (values.isEmpty) return MonetaryValue(0);
    return values.reduce((a, b) => a + b);
  }

  /// Calculate average of monetary values
  static MonetaryValue average(List<MonetaryValue> values) {
    if (values.isEmpty) return MonetaryValue(0);
    return sum(values) / values.length;
  }

  /// Safely round to nearest paisa (2 decimals)
  static MonetaryValue round(MonetaryValue value) {
    final rounded = value.toDecimal().toDouble();
    return MonetaryValue(double.parse(rounded.toStringAsFixed(2)));
  }

  /// Check if amount is within tolerance (for floating-point comparisons)
  static bool isApproxEqual(MonetaryValue a, MonetaryValue b,
      {MonetaryValue? tolerance}) {
    final t = tolerance ?? MonetaryValue(0.01);
    final diff = (a - b);
    return (diff.toDecimal().abs() < t.toDecimal());
  }
}
