import 'package:cloud_firestore/cloud_firestore.dart';

/// The event/schedule that causes a rule to be evaluated.
enum AutomationTriggerType { orderStatusChanged, lowStock, cartAbandoned, customerInactive }

extension AutomationTriggerTypeX on AutomationTriggerType {
  /// Wire value stored in Firestore (must match functions/automation_rules_engine.js).
  String get wireValue {
    switch (this) {
      case AutomationTriggerType.orderStatusChanged:
        return 'order_status_changed';
      case AutomationTriggerType.lowStock:
        return 'low_stock';
      case AutomationTriggerType.cartAbandoned:
        return 'cart_abandoned';
      case AutomationTriggerType.customerInactive:
        return 'customer_inactive';
    }
  }

  String get label {
    switch (this) {
      case AutomationTriggerType.orderStatusChanged:
        return 'Order status changed';
      case AutomationTriggerType.lowStock:
        return 'Product low on stock';
      case AutomationTriggerType.cartAbandoned:
        return 'Cart abandoned';
      case AutomationTriggerType.customerInactive:
        return 'Customer inactive';
    }
  }

  static AutomationTriggerType fromWire(String? value) {
    switch (value) {
      case 'low_stock':
        return AutomationTriggerType.lowStock;
      case 'cart_abandoned':
        return AutomationTriggerType.cartAbandoned;
      case 'customer_inactive':
        return AutomationTriggerType.customerInactive;
      case 'order_status_changed':
      default:
        return AutomationTriggerType.orderStatusChanged;
    }
  }
}

/// The effect a rule has when it matches.
enum AutomationActionType { sendPush, sendEmail, applyCoupon, addUserTag, notifyOwner }

extension AutomationActionTypeX on AutomationActionType {
  String get wireValue {
    switch (this) {
      case AutomationActionType.sendPush:
        return 'send_push';
      case AutomationActionType.sendEmail:
        return 'send_email';
      case AutomationActionType.applyCoupon:
        return 'apply_coupon';
      case AutomationActionType.addUserTag:
        return 'add_user_tag';
      case AutomationActionType.notifyOwner:
        return 'notify_owner';
    }
  }

  String get label {
    switch (this) {
      case AutomationActionType.sendPush:
        return 'Send push + in-app notification';
      case AutomationActionType.sendEmail:
        return 'Send email';
      case AutomationActionType.applyCoupon:
        return 'Apply coupon';
      case AutomationActionType.addUserTag:
        return 'Add user tag';
      case AutomationActionType.notifyOwner:
        return 'Notify owner/manager';
    }
  }

  static AutomationActionType fromWire(String? value) {
    switch (value) {
      case 'send_email':
        return AutomationActionType.sendEmail;
      case 'apply_coupon':
        return AutomationActionType.applyCoupon;
      case 'add_user_tag':
        return AutomationActionType.addUserTag;
      case 'notify_owner':
        return AutomationActionType.notifyOwner;
      case 'send_push':
      default:
        return AutomationActionType.sendPush;
    }
  }
}

/// A single `field operator value` check evaluated against the trigger's event data.
class AutomationCondition {
  final String field;
  final String operator; // ==, !=, >, >=, <, <=, contains, exists, not_exists
  final String value;

  const AutomationCondition({required this.field, required this.operator, this.value = ''});

  factory AutomationCondition.fromMap(Map<String, dynamic> map) {
    return AutomationCondition(
      field: map['field'] as String? ?? '',
      operator: map['operator'] as String? ?? '==',
      value: map['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'field': field, 'operator': operator, 'value': value};

  AutomationCondition copyWith({String? field, String? operator, String? value}) {
    return AutomationCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }
}

/// A single effect to run when a rule matches. `config` keys depend on [type]
/// and support `{{field.path}}` templating against the event data
/// (see functions/automation_rules_engine.js for the full contract).
class AutomationAction {
  final AutomationActionType type;
  final Map<String, dynamic> config;

  const AutomationAction({required this.type, this.config = const {}});

  factory AutomationAction.fromMap(Map<String, dynamic> map) {
    return AutomationAction(
      type: AutomationActionTypeX.fromWire(map['type'] as String?),
      config: map['config'] != null ? Map<String, dynamic>.from(map['config'] as Map) : {},
    );
  }

  Map<String, dynamic> toMap() => {'type': type.wireValue, 'config': config};

  AutomationAction copyWith({AutomationActionType? type, Map<String, dynamic>? config}) {
    return AutomationAction(type: type ?? this.type, config: config ?? this.config);
  }
}

/// An owner-configurable "if this happens, then do that" rule.
class AutomationRuleModel {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final AutomationTriggerType triggerType;
  final Map<String, dynamic> triggerConfig;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final int triggeredCount;
  final DateTime? lastTriggeredAt;
  final DateTime? createdAt;

  const AutomationRuleModel({
    this.id = '',
    required this.name,
    this.description = '',
    this.enabled = true,
    required this.triggerType,
    this.triggerConfig = const {},
    this.conditions = const [],
    this.actions = const [],
    this.triggeredCount = 0,
    this.lastTriggeredAt,
    this.createdAt,
  });

  factory AutomationRuleModel.fromMap(Map<String, dynamic> map, String id) {
    final trigger = map['trigger'] != null ? Map<String, dynamic>.from(map['trigger'] as Map) : {};
    final stats = map['stats'] != null ? Map<String, dynamic>.from(map['stats'] as Map) : {};

    return AutomationRuleModel(
      id: id,
      name: map['name'] as String? ?? 'Untitled rule',
      description: map['description'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      triggerType: AutomationTriggerTypeX.fromWire(trigger['type'] as String?),
      triggerConfig: trigger['config'] != null
          ? Map<String, dynamic>.from(trigger['config'] as Map)
          : {},
      conditions: (map['conditions'] as List? ?? [])
          .map((c) => AutomationCondition.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      actions: (map['actions'] as List? ?? [])
          .map((a) => AutomationAction.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      triggeredCount: (stats['triggeredCount'] as num?)?.toInt() ?? 0,
      lastTriggeredAt: (stats['lastTriggeredAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'enabled': enabled,
    'trigger': {'type': triggerType.wireValue, 'config': triggerConfig},
    'conditions': conditions.map((c) => c.toMap()).toList(),
    'actions': actions.map((a) => a.toMap()).toList(),
    if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    if (id.isEmpty) 'stats': {'triggeredCount': 0, 'lastTriggeredAt': null},
  };

  AutomationRuleModel copyWith({
    String? name,
    String? description,
    bool? enabled,
    AutomationTriggerType? triggerType,
    Map<String, dynamic>? triggerConfig,
    List<AutomationCondition>? conditions,
    List<AutomationAction>? actions,
  }) {
    return AutomationRuleModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      triggerType: triggerType ?? this.triggerType,
      triggerConfig: triggerConfig ?? this.triggerConfig,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      triggeredCount: triggeredCount,
      lastTriggeredAt: lastTriggeredAt,
      createdAt: createdAt,
    );
  }
}
