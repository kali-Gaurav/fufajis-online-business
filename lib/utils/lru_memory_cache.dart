import 'package:flutter/foundation.dart';

class _LruNode<K, V> {
  final K key;
  V value;
  final DateTime expiryTime;
  _LruNode<K, V>? prev;
  _LruNode<K, V>? next;

  _LruNode({
    required this.key,
    required this.value,
    required this.expiryTime,
  });

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

/// Generic High-Performance Least Recently Used (LRU) Cache (O(1) Get/Set)
/// Implements standard Doubly-Linked List + HashMap design pattern with TTL support.
class LruMemoryCache<K, V> {
  final int capacity;
  final Duration ttl;
  final Map<K, _LruNode<K, V>> _map = {};
  
  _LruNode<K, V>? _head;
  _LruNode<K, V>? _tail;

  LruMemoryCache({
    required this.capacity,
    this.ttl = const Duration(minutes: 30),
  }) {
    assert(capacity > 0);
  }

  /// Get item from cache
  V? get(K key) {
    final node = _map[key];
    if (node == null) return null;

    if (node.isExpired) {
      debugPrint('[LRUCache] Evicting expired key: $key');
      _removeNode(node);
      _map.remove(key);
      return null;
    }

    _moveToHead(node);
    return node.value;
  }

  /// Set/Update item in cache
  void set(K key, V value) {
    final expiry = DateTime.now().add(ttl);
    final existingNode = _map[key];

    if (existingNode != null) {
      existingNode.value = value;
      _moveToHead(existingNode);
      return;
    }

    final newNode = _LruNode<K, V>(key: key, value: value, expiryTime: expiry);
    _map[key] = newNode;
    _addToHead(newNode);

    if (_map.length > capacity) {
      final tailNode = _tail;
      if (tailNode != null) {
        debugPrint('[LRUCache] Capacity limit hit ($capacity). Evicting LRU key: ${tailNode.key}');
        _removeNode(tailNode);
        _map.remove(tailNode.key);
      }
    }
  }

  /// Remove item from cache
  void remove(K key) {
    final node = _map.remove(key);
    if (node != null) {
      _removeNode(node);
    }
  }

  /// Check if key exists in cache without shifting MRU priority
  bool containsKey(K key) {
    final node = _map[key];
    if (node == null) return false;
    if (node.isExpired) {
      _removeNode(node);
      _map.remove(key);
      return false;
    }
    return true;
  }

  /// Clear all cache contents
  void clear() {
    _map.clear();
    _head = null;
    _tail = null;
  }

  // ─────────────── Private List Helpers ───────────────

  void _addToHead(_LruNode<K, V> node) {
    node.next = _head;
    node.prev = null;

    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;

    if (_tail == null) {
      _tail = node;
    }
  }

  void _removeNode(_LruNode<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }

    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }
  }

  void _moveToHead(_LruNode<K, V> node) {
    _removeNode(node);
    _addToHead(node);
  }
}
