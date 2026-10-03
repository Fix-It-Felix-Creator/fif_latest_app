import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The service catalogue, read from bundled assets.
///
/// Deliberately not wired to Supabase yet. The admin panel is now the source
/// of truth for these — `public.services` holds the same 37 flows — but this
/// app reads the local copy so the screens can be built and judged before the
/// fetch, cache and offline story are decided. Swapping the loader is the only
/// change that will be needed: nothing above [ServiceCatalog] knows where the
/// data came from.
class ServiceCatalog {
  ServiceCatalog._(this.services);

  final List<ServiceSummary> services;

  static ServiceCatalog? _cached;

  static const _indexPath = 'assets/documents/services/services_index.json';

  /// Loads the index once per process.
  ///
  /// Only the index — 26 tiles' worth of metadata — is read up front. A
  /// service's flow is a separate file of up to 14KB and is loaded when
  /// someone actually taps that tile, because parsing 37 of them to draw a
  /// home screen would be work nobody asked for.
  static Future<ServiceCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_indexPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['services'] as List<dynamic>? ?? [])
          .map((e) => ServiceSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final catalog = ServiceCatalog._(list);
      _cached = catalog;
      return catalog;
    } catch (e) {
      debugPrint('ServiceCatalog: could not read $_indexPath — $e');
      return ServiceCatalog._(const []);
    }
  }

  ServiceSummary? byId(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Services grouped under their catalogue heading, in the index's order.
  Map<String, List<ServiceSummary>> get byGroup {
    final out = <String, List<ServiceSummary>>{};
    for (final s in services) {
      out.putIfAbsent(s.category ?? 'Other', () => []).add(s);
    }
    return out;
  }

  List<ServiceSummary> get popular =>
      services.where((s) => s.isPopular).toList();
}

/// One tile on the home screen.
@immutable
class ServiceSummary {
  const ServiceSummary({
    required this.id,
    required this.name,
    this.subtitle,
    this.description,
    this.icon,
    this.colorHex,
    this.category,
    this.isPopular = false,
    this.hasEmergency = false,
  });

  final String id;
  final String name;
  final String? subtitle;
  final String? description;
  final String? icon;
  final String? colorHex;
  final String? category;
  final bool isPopular;
  final bool hasEmergency;

  /// Bundled artwork for this service, or null when there is none.
  ///
  /// Twelve of the services have a picture and the rest do not, so callers
  /// must handle the absence — a tile falls back to its icon and colour.
  String get imageAsset => 'assets/images/services/$id.jpg';

  factory ServiceSummary.fromJson(Map<String, dynamic> json) => ServiceSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        colorHex: json['color'] as String?,
        category: json['category'] as String?,
        isPopular: json['isPopular'] as bool? ?? false,
        hasEmergency: json['hasEmergency'] as bool? ?? false,
      );
}

/// A service's question flow: the heading, and the tree beneath it.
@immutable
class ServiceFlow {
  const ServiceFlow({
    required this.serviceId,
    required this.title,
    required this.subtitle,
    required this.categories,
  });

  final String serviceId;
  final String title;
  final String subtitle;
  final List<FlowOption> categories;

  static final Map<String, ServiceFlow> _cache = {};

  /// Reads one service's flow, cached after the first read.
  static Future<ServiceFlow?> load(String serviceId) async {
    final hit = _cache[serviceId];
    if (hit != null) return hit;

    try {
      final raw = await rootBundle
          .loadString('assets/documents/services/$serviceId.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final flow = ServiceFlow(
        serviceId: serviceId,
        title: json['title'] as String? ?? 'What do you need?',
        subtitle: json['subtitle'] as String? ?? '',
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => FlowOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _cache[serviceId] = flow;
      return flow;
    } catch (e) {
      debugPrint('ServiceFlow: could not read $serviceId — $e');
      return null;
    }
  }
}

/// A node in the question tree.
///
/// One type for every level. A category, an option and a sub-option differ
/// only in where they sit, so modelling them separately would mean three
/// near-identical classes and a walker that has to know which level it is on.
@immutable
class FlowOption {
  const FlowOption({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    this.urgent = false,
    this.requiresDescription = false,
    this.options = const [],
  });

  final String id;
  final String name;
  final String? icon;
  final String? description;

  /// Marks an emergency branch, shown with a warning tone.
  final bool urgent;

  /// This branch needs the customer to type something before continuing.
  final bool requiresDescription;

  final List<FlowOption> options;

  bool get hasChildren => options.isNotEmpty;

  factory FlowOption.fromJson(Map<String, dynamic> json) => FlowOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String?,
        description: json['description'] as String?,
        urgent: json['urgent'] as bool? ?? false,
        requiresDescription: json['requiresDescription'] as bool? ?? false,
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => FlowOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
