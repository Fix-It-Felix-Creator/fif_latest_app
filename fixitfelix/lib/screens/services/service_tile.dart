import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/services/service_catalog.dart';

/// Turns a service's `#RRGGBB` into a Color, falling back to the brand.
/// Colours for the icon tiles down a list of flow options.
///
/// Cycled by position rather than hashed from the option's name: a hash gives
/// a stable colour per option but lets two neighbours land on the same hue,
/// which reads as a mistake. Cycling guarantees adjacent rows always differ,
/// and position is stable for a given level so nothing shifts under you.
///
/// Eight hues, each legible at full strength on its own 12%-alpha tile.
const _optionAccents = <Color>[
  Color(0xFF6366F1), // indigo
  Color(0xFF10B981), // emerald
  Color(0xFF3B82F6), // blue
  Color(0xFFF59E0B), // amber
  Color(0xFF8B5CF6), // violet
  Color(0xFF06B6D4), // cyan
  Color(0xFFF43F5E), // rose
  Color(0xFF84CC16), // lime
];

/// The accent for the option at [index] in its list.
Color optionAccent(int index) =>
    _optionAccents[index % _optionAccents.length];

Color serviceColor(ServiceSummary s) {
  final hex = s.colorHex;
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
    return const Color(0xFFF64C13);
  }
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// The lucide glyph named in the catalogue.
///
/// The index stores an icon NAME, and Dart cannot look one up by string
/// without shipping the whole icon font's symbol table. This maps the ones
/// actually in use; anything else gets a generic wrench, which is a fine tile
/// and a bad reason to block a service from appearing.
IconData serviceIcon(String? name) {
  switch (name) {
    case 'pipette':
      return LucideIcons.pipette;
    case 'zap':
      return LucideIcons.zap;
    case 'paintbrush':
      return LucideIcons.paintbrush;
    case 'hammer':
      return LucideIcons.hammer;
    case 'wrench':
      return LucideIcons.wrench;
    case 'home':
    case 'house':
      return LucideIcons.house;
    case 'brick-wall':
    case 'brickWall':
      return LucideIcons.brickWall;
    case 'grid':
      return LucideIcons.grid3x3;
    case 'flame':
      return LucideIcons.flame;
    case 'trees':
    case 'tree':
      return LucideIcons.trees;
    case 'sprout':
      return LucideIcons.sprout;
    case 'car':
      return LucideIcons.car;
    case 'key':
    case 'key-round':
      return LucideIcons.keyRound;
    case 'sparkles':
      return LucideIcons.sparkles;
    case 'scissors':
      return LucideIcons.scissors;
    case 'thermometer':
      return LucideIcons.thermometer;
    case 'wind':
      return LucideIcons.wind;
    case 'utensils':
      return LucideIcons.utensils;
    case 'layers':
      return LucideIcons.layers;
    case 'square':
      return LucideIcons.square;
    case 'hard-hat':
    case 'hardHat':
      return LucideIcons.hardHat;
    default:
      return LucideIcons.wrench;
  }
}

/// The artwork behind a tile, or a tinted icon when there is none.
///
/// Twelve services have a photograph and the rest do not, so this is the
/// difference between a catalogue that looks half-finished and one that looks
/// deliberate: no picture means a large glyph on the service's own colour.
class ServiceArtwork extends StatelessWidget {
  const ServiceArtwork({super.key, required this.service, this.radius = 20});

  final ServiceSummary service;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = serviceColor(service);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        service.imageAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: color.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Icon(serviceIcon(service.icon), size: 28, color: color),
        ),
      ),
    );
  }
}

/// A service as a wide row, for the full list.
/// One service as a row inside an [InsetGroup].
///
/// Flat on purpose: no card, no border, no radius of its own. The group it
/// sits in is the card, and a row that draws its own chrome inside one looks
/// like a box inside a box.
class ServiceRow extends StatelessWidget {
  const ServiceRow({super.key, required this.service, required this.onTap});

  final ServiceSummary service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              // foregroundDecoration, not decoration: a border in decoration
              // paints behind the child, and the artwork fills the box.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: ServiceArtwork(service: service, radius: 10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (service.hasEmergency) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '24/7',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((service.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      service.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceGridTile extends StatelessWidget {
  const ServiceGridTile({
    super.key,
    required this.service,
    required this.onTap,
  });

  final ServiceSummary service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square, and stated rather than implied. This was Expanded, so the
          // artwork got whatever height the name did not use — meaning a
          // two-line name made the image shorter than a one-line name, and
          // neither matched the square the admin panel crops to.
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // foregroundDecoration, not decoration: a border in `decoration`
              // paints BEHIND the child, and the artwork fills the box edge to
              // edge — so the line was there all along and covered by the
              // photograph. This draws it over the top.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: ServiceArtwork(service: service, radius: 8),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
