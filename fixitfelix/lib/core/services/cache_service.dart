import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache box names - maps to root database collections
class CacheBoxes {
  static const String userDetails = 'user_details_cache';
  static const String invoices = 'invoices_cache';
  static const String services = 'services_cache';
  static const String templates = 'templates_cache';
  static const String customers = 'customers_cache';
  static const String quotations = 'quotations_cache';
  static const String jobs = 'jobs_cache';
  static const String settings = 'settings_cache';
  static const String syncQueue = 'sync_queue';
  static const String savedAddresses = 'saved_addresses_cache';
  static const String properties = 'properties_cache';
  static const String projects = 'projects_cache';
  static const String scratchPad = 'scratch_pad_cache';
}

/// Cache keys
class CacheKeys {
  static const String currentUser = 'current_user';
  static const String lastSyncTime = 'last_sync_time';
  static const String pendingChanges = 'pending_changes';
}

/// Service for managing local cache using Hive
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  bool _isInitialized = false;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Open all cache boxes
      await Future.wait([
        Hive.openBox(CacheBoxes.userDetails),
        Hive.openBox(CacheBoxes.invoices),
        Hive.openBox(CacheBoxes.services),
        Hive.openBox(CacheBoxes.templates),
        Hive.openBox(CacheBoxes.customers),
        Hive.openBox(CacheBoxes.quotations),
        Hive.openBox(CacheBoxes.jobs),
        Hive.openBox(CacheBoxes.settings),
        Hive.openBox(CacheBoxes.syncQueue),
        Hive.openBox(CacheBoxes.savedAddresses),
        Hive.openBox(CacheBoxes.properties),
        Hive.openBox(CacheBoxes.projects),
        Hive.openBox(CacheBoxes.scratchPad),
      ]);

      _isInitialized = true;
      debugPrint('CacheService initialized successfully');
    } catch (e) {
      debugPrint('CacheService initialization error: $e');
    }
  }

  /// Get a box by name
  Box? _getBox(String boxName) {
    try {
      return Hive.box(boxName);
    } catch (e) {
      debugPrint('Error getting box $boxName: $e');
      return null;
    }
  }

  // ============================================
  // Generic Cache Operations
  // ============================================

  /// Save data to cache
  Future<void> put(String boxName, String key, dynamic value) async {
    try {
      final box = _getBox(boxName);
      if (box != null) {
        if (value is Map || value is List) {
          await box.put(key, jsonEncode(value));
        } else {
          await box.put(key, value);
        }
      }
    } catch (e) {
      debugPrint('Cache put error: $e');
    }
  }

  /// Get data from cache
  T? get<T>(String boxName, String key, {T? defaultValue}) {
    try {
      final box = _getBox(boxName);
      if (box != null) {
        final value = box.get(key, defaultValue: defaultValue);
        if (value is String && (T == Map || T == List)) {
          return jsonDecode(value) as T?;
        }
        return value as T?;
      }
    } catch (e) {
      debugPrint('Cache get error: $e');
    }
    return defaultValue;
  }

  /// Get JSON data from cache
  Map<String, dynamic>? getJson(String boxName, String key) {
    try {
      final box = _getBox(boxName);
      if (box != null) {
        final value = box.get(key);
        if (value is String) {
          return jsonDecode(value) as Map<String, dynamic>;
        } else if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
    } catch (e) {
      debugPrint('Cache getJson error: $e');
    }
    return null;
  }

  /// Get list from cache
  List<Map<String, dynamic>> getJsonList(String boxName, String key) {
    try {
      final box = _getBox(boxName);
      if (box != null) {
        final value = box.get(key);
        if (value is String) {
          final decoded = jsonDecode(value) as List;
          return decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else if (value is List) {
          return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Cache getJsonList error: $e');
    }
    return [];
  }

  /// Delete data from cache
  Future<void> delete(String boxName, String key) async {
    try {
      final box = _getBox(boxName);
      await box?.delete(key);
    } catch (e) {
      debugPrint('Cache delete error: $e');
    }
  }

  /// Clear all data in a box
  Future<void> clearBox(String boxName) async {
    try {
      final box = _getBox(boxName);
      await box?.clear();
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    try {
      await Future.wait([
        clearBox(CacheBoxes.userDetails),
        clearBox(CacheBoxes.invoices),
        clearBox(CacheBoxes.services),
        clearBox(CacheBoxes.templates),
        clearBox(CacheBoxes.customers),
        clearBox(CacheBoxes.quotations),
        clearBox(CacheBoxes.jobs),
        clearBox(CacheBoxes.syncQueue),
        clearBox(CacheBoxes.properties),
        clearBox(CacheBoxes.projects),
      ]);
    } catch (e) {
      debugPrint('Cache clearAll error: $e');
    }
  }

  // ============================================
  // User Details Cache
  // ============================================

  /// Save user details to cache
  Future<void> saveUserDetails(
    String uid,
    Map<String, dynamic> userDetails,
  ) async {
    await put(CacheBoxes.userDetails, uid, userDetails);
    await put(CacheBoxes.userDetails, CacheKeys.currentUser, uid);
    await put(
      CacheBoxes.userDetails,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached user details
  Map<String, dynamic>? getUserDetails(String uid) {
    return getJson(CacheBoxes.userDetails, uid);
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return get<String>(CacheBoxes.userDetails, CacheKeys.currentUser);
  }

  /// Get last sync time for user
  DateTime? getLastSyncTime(String uid) {
    final timeStr = get<String>(CacheBoxes.userDetails, '${uid}_lastSync');
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  /// Check if cache is stale (older than specified duration)
  bool isCacheStale(
    String uid, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final lastSync = getLastSyncTime(uid);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  // ============================================
  // Invoices Cache
  // ============================================

  /// Save invoices to cache
  Future<void> saveInvoices(
    String uid,
    List<Map<String, dynamic>> invoices,
  ) async {
    await put(CacheBoxes.invoices, uid, invoices);
    await put(
      CacheBoxes.invoices,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached invoices
  List<Map<String, dynamic>> getInvoices(String uid) {
    return getJsonList(CacheBoxes.invoices, uid);
  }

  // ============================================
  // Services Cache (services/{uid}/services)
  // ============================================

  /// Save services to cache
  Future<void> saveServices(
    String uid,
    List<Map<String, dynamic>> services,
  ) async {
    await put(CacheBoxes.services, uid, services);
    await put(
      CacheBoxes.services,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached services
  List<Map<String, dynamic>> getServices(String uid) {
    return getJsonList(CacheBoxes.services, uid);
  }

  // ============================================
  // Templates Cache (templates/{uid}/invoiceTemplates)
  // ============================================

  /// Save templates to cache
  Future<void> saveTemplates(
    String uid,
    List<Map<String, dynamic>> templates,
  ) async {
    await put(CacheBoxes.templates, uid, templates);
    await put(
      CacheBoxes.templates,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached templates
  List<Map<String, dynamic>> getTemplates(String uid) {
    return getJsonList(CacheBoxes.templates, uid);
  }

  // ============================================
  // Customers Cache (customers/{uid}/customers)
  // ============================================

  /// Save customers to cache
  Future<void> saveCustomers(
    String uid,
    List<Map<String, dynamic>> customers,
  ) async {
    await put(CacheBoxes.customers, uid, customers);
    await put(
      CacheBoxes.customers,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached customers
  List<Map<String, dynamic>> getCustomers(String uid) {
    return getJsonList(CacheBoxes.customers, uid);
  }

  // ============================================
  // Quotations Cache (quotations/{uid}/quotations)
  // ============================================

  /// Save quotations to cache
  Future<void> saveQuotations(
    String uid,
    List<Map<String, dynamic>> quotations,
  ) async {
    await put(CacheBoxes.quotations, uid, quotations);
    await put(
      CacheBoxes.quotations,
      '${uid}_lastSync',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached quotations
  List<Map<String, dynamic>> getQuotations(String uid) {
    return getJsonList(CacheBoxes.quotations, uid);
  }

  // ============================================
  // Offline Sync Queue
  // ============================================

  /// Add operation to sync queue for offline changes
  Future<void> addToSyncQueue(
    String uid,
    Map<String, dynamic> operation,
  ) async {
    final queue = getSyncQueue(uid);
    queue.add({...operation, 'timestamp': DateTime.now().toIso8601String()});
    await put(CacheBoxes.syncQueue, uid, queue);
  }

  /// Get pending sync operations
  List<Map<String, dynamic>> getSyncQueue(String uid) {
    return getJsonList(CacheBoxes.syncQueue, uid);
  }

  /// Clear sync queue after successful sync
  Future<void> clearSyncQueue(String uid) async {
    await delete(CacheBoxes.syncQueue, uid);
  }

  /// Check if there are pending changes
  bool hasPendingChanges(String uid) {
    return getSyncQueue(uid).isNotEmpty;
  }

  /// Get count of pending sync operations
  int getPendingSyncCount(String uid) {
    return getSyncQueue(uid).length;
  }

  /// Remove specific operation from sync queue
  Future<void> removeFromSyncQueue(String uid, String operationId) async {
    final queue = getSyncQueue(uid);
    queue.removeWhere((op) => op['id'] == operationId);
    await put(CacheBoxes.syncQueue, uid, queue);
  }

  /// Update operation in sync queue (e.g., increment retry count)
  Future<void> updateSyncQueueOperation(
    String uid,
    String operationId,
    Map<String, dynamic> updates,
  ) async {
    final queue = getSyncQueue(uid);
    final index = queue.indexWhere((op) => op['id'] == operationId);
    if (index != -1) {
      queue[index] = {...queue[index], ...updates};
      await put(CacheBoxes.syncQueue, uid, queue);
    }
  }

  // ============================================
  // Saved Addresses Cache
  // ============================================

  /// Save addresses to cache
  Future<void> saveSavedAddresses(List<Map<String, dynamic>> addresses) async {
    await put(CacheBoxes.savedAddresses, 'addresses', addresses);
  }

  /// Get cached saved addresses
  List<Map<String, dynamic>> getSavedAddresses() {
    return getJsonList(CacheBoxes.savedAddresses, 'addresses');
  }

  /// Add a new address
  Future<void> addSavedAddress(Map<String, dynamic> address) async {
    final addresses = getSavedAddresses();
    addresses.add(address);
    await saveSavedAddresses(addresses);
  }

  /// Update an address at index
  Future<void> updateSavedAddress(
    int index,
    Map<String, dynamic> address,
  ) async {
    final addresses = getSavedAddresses();
    if (index >= 0 && index < addresses.length) {
      addresses[index] = address;
      await saveSavedAddresses(addresses);
    }
  }

  /// Remove an address at index
  Future<void> removeSavedAddress(int index) async {
    final addresses = getSavedAddresses();
    if (index >= 0 && index < addresses.length) {
      addresses.removeAt(index);
      await saveSavedAddresses(addresses);
    }
  }

  // ============================================
  // Current Location Cache
  // ============================================

  /// Save current location to cache
  Future<void> saveCurrentLocation({
    required String address,
    required double lat,
    required double lng,
  }) async {
    await put(CacheBoxes.settings, 'current_location', {
      'address': address,
      'lat': lat,
      'lng': lng,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get cached current location
  Map<String, dynamic>? getCurrentLocation() {
    return getJson(CacheBoxes.settings, 'current_location');
  }

  /// Check if location is saved
  bool hasCurrentLocation() {
    return getCurrentLocation() != null;
  }

  /// Clear current location
  Future<void> clearCurrentLocation() async {
    await delete(CacheBoxes.settings, 'current_location');
  }
}
