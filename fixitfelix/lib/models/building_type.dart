import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum BuildingType {
  detached,
  semiDetached,
  terraced,
  flat,
  bungalow,
  cottage,
  condo,
  villa,
  townhouse,
  commercial,
  office,
  other;

  String get displayName {
    switch (this) {
      case BuildingType.detached:
        return 'Detached';
      case BuildingType.semiDetached:
        return 'Semi-Detached';
      case BuildingType.terraced:
        return 'Terraced';
      case BuildingType.flat:
        return 'Flat / Apartment';
      case BuildingType.bungalow:
        return 'Bungalow';
      case BuildingType.cottage:
        return 'Cottage';
      case BuildingType.condo:
        return 'Condo';
      case BuildingType.villa:
        return 'Villa';
      case BuildingType.townhouse:
        return 'Townhouse';
      case BuildingType.commercial:
        return 'Commercial';
      case BuildingType.office:
        return 'Office';
      case BuildingType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case BuildingType.detached:
        return LucideIcons.house;
      case BuildingType.semiDetached:
        return LucideIcons.housePlus;
      case BuildingType.terraced:
        return LucideIcons.layoutList;
      case BuildingType.flat:
        return LucideIcons.building;
      case BuildingType.bungalow:
        return LucideIcons.doorOpen;
      case BuildingType.cottage:
        return LucideIcons.trees;
      case BuildingType.condo:
        return LucideIcons.building2;
      case BuildingType.villa:
        return LucideIcons.castle;
      case BuildingType.townhouse:
        return LucideIcons.hotel;
      case BuildingType.commercial:
        return LucideIcons.store;
      case BuildingType.office:
        return LucideIcons.briefcase;
      case BuildingType.other:
        return LucideIcons.mapPin;
    }
  }

  Color get color {
    switch (this) {
      case BuildingType.detached:
        return const Color(0xFF22C55E); // green
      case BuildingType.semiDetached:
        return const Color(0xFF10B981); // emerald
      case BuildingType.terraced:
        return const Color(0xFF14B8A6); // teal
      case BuildingType.flat:
        return const Color(0xFF3B82F6); // blue
      case BuildingType.bungalow:
        return const Color(0xFFF97316); // orange
      case BuildingType.cottage:
        return const Color(0xFF84CC16); // lime
      case BuildingType.condo:
        return const Color(0xFF06B6D4); // cyan
      case BuildingType.villa:
        return const Color(0xFFA855F7); // purple
      case BuildingType.townhouse:
        return const Color(0xFF8B5CF6); // violet
      case BuildingType.commercial:
        return const Color(0xFFF59E0B); // amber
      case BuildingType.office:
        return const Color(0xFF6366F1); // indigo
      case BuildingType.other:
        return const Color(0xFF6B7280); // gray
    }
  }

  static BuildingType? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return BuildingType.values.firstWhere(
        (e) => e.name == value,
      );
    } catch (_) {
      return null;
    }
  }
}
