import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Common tradesman service item used across authentication screens
class TradesmanServiceItem {
  final String name;
  final String key;
  final IconData icon;
  final String subtitle;
  final String color;

  const TradesmanServiceItem({
    required this.name,
    required this.key,
    required this.icon,
    required this.subtitle,
    required this.color,
  });
}

/// List of all tradesman services available for selection
/// Used by BusinessServiceSelectionScreen and TradesmanServiceSelectionScreen
const List<TradesmanServiceItem> tradesmanServices = [
  TradesmanServiceItem(
    name: 'Plumber',
    key: 'plumber',
    icon: LucideIcons.pipette,
    subtitle: 'Leaks, pipes, taps & drains',
    color: '#3B82F6',
  ),
  TradesmanServiceItem(
    name: 'Electrician',
    key: 'electrician',
    icon: LucideIcons.zap,
    subtitle: 'Wiring, sockets & lighting',
    color: '#F59E0B',
  ),
  TradesmanServiceItem(
    name: 'Roofer',
    key: 'roofer',
    icon: LucideIcons.house,
    subtitle: 'Roof repairs & installations',
    color: '#DC2626',
  ),
  TradesmanServiceItem(
    name: 'Builder',
    key: 'builder',
    icon: LucideIcons.building2,
    subtitle: 'Extensions, renovations & structural',
    color: '#78716C',
  ),
  TradesmanServiceItem(
    name: 'Gardener',
    key: 'gardener',
    icon: LucideIcons.flower2,
    subtitle: 'Lawn care & landscaping',
    color: '#22C55E',
  ),
  TradesmanServiceItem(
    name: 'Painter',
    key: 'painter',
    icon: LucideIcons.paintbrush,
    subtitle: 'Interior & exterior painting',
    color: '#10B981',
  ),
  TradesmanServiceItem(
    name: 'Landscaper',
    key: 'landscaper',
    icon: LucideIcons.trees,
    subtitle: 'Garden design & outdoor spaces',
    color: '#059669',
  ),
  TradesmanServiceItem(
    name: 'Carpenter',
    key: 'carpenter',
    icon: LucideIcons.hammer,
    subtitle: 'Doors, furniture & woodwork',
    color: '#8B5CF6',
  ),
  TradesmanServiceItem(
    name: 'Plasterer',
    key: 'plasterer',
    icon: LucideIcons.paintRoller,
    subtitle: 'Plastering & rendering',
    color: '#A3A3A3',
  ),
  TradesmanServiceItem(
    name: 'Tree Surgeon',
    key: 'tree_surgeon',
    icon: LucideIcons.axe,
    subtitle: 'Tree care, pruning & removal',
    color: '#15803D',
  ),
  TradesmanServiceItem(
    name: 'Handyman',
    key: 'handyman',
    icon: LucideIcons.wrench,
    subtitle: 'General repairs & odd jobs',
    color: '#6366F1',
  ),
  TradesmanServiceItem(
    name: 'Locksmith',
    key: 'locksmith',
    icon: LucideIcons.keyRound,
    subtitle: 'Locks, keys & security',
    color: '#EF4444',
  ),
  TradesmanServiceItem(
    name: 'Tiler',
    key: 'tiler',
    icon: LucideIcons.layoutGrid,
    subtitle: 'Wall & floor tiling',
    color: '#EC4899',
  ),
  TradesmanServiceItem(
    name: 'Central Heating',
    key: 'central_heating',
    icon: LucideIcons.thermometer,
    subtitle: 'Heating systems & radiators',
    color: '#EA580C',
  ),
  TradesmanServiceItem(
    name: 'Boiler Repair',
    key: 'boiler_repair',
    icon: LucideIcons.flame,
    subtitle: 'Boiler repairs & servicing',
    color: '#B91C1C',
  ),
  TradesmanServiceItem(
    name: 'Mechanic',
    key: 'mechanic',
    icon: LucideIcons.car,
    subtitle: 'Vehicle repairs & servicing',
    color: '#374151',
  ),
  TradesmanServiceItem(
    name: 'Cleaner',
    key: 'cleaner',
    icon: LucideIcons.sparkles,
    subtitle: 'Domestic & commercial cleaning',
    color: '#7C3AED',
  ),
  TradesmanServiceItem(
    name: 'Glazier',
    key: 'glazier',
    icon: LucideIcons.doorOpen,
    subtitle: 'Windows, doors & glazing',
    color: '#0EA5E9',
  ),
  TradesmanServiceItem(
    name: 'Gas Engineer',
    key: 'gas_engineer',
    icon: LucideIcons.flame,
    subtitle: 'Gas appliances & safety',
    color: '#F97316',
  ),
  TradesmanServiceItem(
    name: 'HVAC Technician',
    key: 'hvac_technician',
    icon: LucideIcons.airVent,
    subtitle: 'AC, heat pumps & refrigeration',
    color: '#06B6D4',
  ),
  TradesmanServiceItem(
    name: 'Scaffolder',
    key: 'scaffolder',
    icon: LucideIcons.construction,
    subtitle: 'Scaffolding erection & dismantling',
    color: '#78716C',
  ),
  TradesmanServiceItem(
    name: 'Welder',
    key: 'welder',
    icon: LucideIcons.shield,
    subtitle: 'Welding, gates & metal fabrication',
    color: '#71717A',
  ),
  TradesmanServiceItem(
    name: 'Kitchen Fitter',
    key: 'kitchen_fitter',
    icon: LucideIcons.chefHat,
    subtitle: 'Kitchen installation & fitting',
    color: '#D946EF',
  ),
  TradesmanServiceItem(
    name: 'Hairdresser',
    key: 'hairdresser',
    icon: LucideIcons.scissors,
    subtitle: 'Cuts, styling, colouring & treatments',
    color: '#E11D48',
  ),
  TradesmanServiceItem(
    name: 'Labourer',
    key: 'labourer',
    icon: LucideIcons.hardHat,
    subtitle: 'General labour & site work',
    color: '#92400E',
  ),
  TradesmanServiceItem(
    name: 'Window Cleaner',
    key: 'window_cleaner',
    icon: LucideIcons.droplets,
    subtitle: 'Residential & commercial window cleaning',
    color: '#0284C7',
  ),
];

/// Format a trade key (e.g., 'boiler_repair') into a display name (e.g., 'Boiler Repair').
/// First looks up the known services list for an exact match, then falls back to
/// converting underscores to spaces and capitalizing each word.
String formatTradeDisplayName(String tradeKey) {
  if (tradeKey.isEmpty) return '';

  // Look up in known services
  for (final service in tradesmanServices) {
    if (service.key == tradeKey) return service.name;
  }

  // Fallback: replace underscores with spaces and capitalize each word
  return tradeKey
      .split('_')
      .map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
