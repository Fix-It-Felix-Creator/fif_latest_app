/// Static data definitions for UK trade competency card schemes.
///
/// Covers CSCS, ECS, JIB-PMES, and Gas Safe Register with their
/// colour-to-qualification mappings and applicable trades.
class TradeCardSchemes {
  TradeCardSchemes._();

  // ============================================
  // Scheme Definitions
  // ============================================

  static const List<CardScheme> schemes = [
    CardScheme(
      id: 'cscs',
      name: 'CSCS',
      fullName: 'Construction Skills Certification Scheme',
      description:
          'Proves competence for workers on construction sites across the UK.',
      applicableTrades: [
        'builder',
        'roofer',
        'plasterer',
        'carpenter',
        'tiler',
        'handyman',
        'glazier',
        'scaffolder',
        'welder',
        'kitchen_fitter',
      ],
      colors: [
        CardColor(
          id: 'green',
          name: 'Green',
          hexColor: 0xFF22C55E,
          qualificationLevel: 'Labourer',
          description: 'Construction Site Operative / Labourer',
        ),
        CardColor(
          id: 'red',
          name: 'Red',
          hexColor: 0xFFEF4444,
          qualificationLevel: 'Apprentice',
          description: 'Trainee / Apprentice working towards NVQ',
        ),
        CardColor(
          id: 'blue',
          name: 'Blue',
          hexColor: 0xFF3B82F6,
          qualificationLevel: 'Skilled Worker',
          description: 'Skilled Worker with NVQ Level 2+',
        ),
        CardColor(
          id: 'gold',
          name: 'Gold',
          hexColor: 0xFFF59E0B,
          qualificationLevel: 'Advanced Craft',
          description: 'Advanced Craft / NVQ Level 3+',
        ),
        CardColor(
          id: 'black',
          name: 'Black',
          hexColor: 0xFF1F2937,
          qualificationLevel: 'Manager / Supervisor',
          description: 'Manager or Supervisor on site',
        ),
        CardColor(
          id: 'white',
          name: 'White',
          hexColor: 0xFFE5E7EB,
          qualificationLevel: 'Academically Qualified',
          description: 'Professionally or Academically Qualified Person',
        ),
      ],
    ),
    CardScheme(
      id: 'ecs',
      name: 'ECS',
      fullName: 'Electrotechnical Certification Scheme',
      description:
          'Industry-standard competency card for electricians and electrical workers.',
      applicableTrades: ['electrician'],
      colors: [
        CardColor(
          id: 'gold',
          name: 'Gold',
          hexColor: 0xFFF59E0B,
          qualificationLevel: 'Approved Electrician',
          description: 'Fully approved JIB-graded electrician',
        ),
        CardColor(
          id: 'blue',
          name: 'Blue',
          hexColor: 0xFF3B82F6,
          qualificationLevel: 'Skilled Electrician',
          description: 'Skilled / JIB Graded Electrician',
        ),
        CardColor(
          id: 'white',
          name: 'White',
          hexColor: 0xFFE5E7EB,
          qualificationLevel: 'Provisional',
          description: 'Provisional - working towards full qualification',
        ),
      ],
    ),
    CardScheme(
      id: 'jib_pmes',
      name: 'JIB-PMES',
      fullName: 'Joint Industry Board - Plumbing & Mechanical Engineering',
      description:
          'Competency card for plumbers and mechanical engineering services workers.',
      applicableTrades: ['plumber', 'central_heating'],
      colors: [
        CardColor(
          id: 'gold',
          name: 'Gold',
          hexColor: 0xFFF59E0B,
          qualificationLevel: 'Qualified Plumber',
          description: 'Fully qualified plumber / mechanical engineer',
        ),
        CardColor(
          id: 'blue',
          name: 'Blue',
          hexColor: 0xFF3B82F6,
          qualificationLevel: 'Trainee / Improver',
          description: 'Trainee or improver working towards qualification',
        ),
      ],
    ),
    CardScheme(
      id: 'gas_safe',
      name: 'Gas Safe',
      fullName: 'Gas Safe Register',
      description:
          'Legal requirement for anyone working on gas appliances in the UK.',
      applicableTrades: ['central_heating', 'boiler_repair', 'gas_engineer'],
      colors: [
        CardColor(
          id: 'standard',
          name: 'Standard ID Card',
          hexColor: 0xFF6366F1,
          qualificationLevel: 'Gas Safe Registered',
          description: 'Registered to work on gas appliances',
        ),
      ],
    ),
    CardScheme(
      id: 'refcom',
      name: 'REFCOM',
      fullName: 'Register of Companies Competent to Manage Refrigerants',
      description:
          'F-Gas company certification for HVAC&R professionals.',
      applicableTrades: ['hvac_technician'],
      colors: [
        CardColor(
          id: 'standard',
          name: 'F-Gas Certified',
          hexColor: 0xFF0891B2,
          qualificationLevel: 'F-Gas Certified',
          description: 'Certified to handle F-Gas refrigerants',
        ),
      ],
    ),
    CardScheme(
      id: 'cisrs',
      name: 'CISRS',
      fullName: 'Construction Industry Scaffolders Record Scheme',
      description:
          'Competency card for scaffolders in the UK construction industry.',
      applicableTrades: ['scaffolder'],
      colors: [
        CardColor(
          id: 'blue',
          name: 'Blue',
          hexColor: 0xFF3B82F6,
          qualificationLevel: 'Scaffolder',
          description: 'Qualified scaffolder',
        ),
        CardColor(
          id: 'red',
          name: 'Red',
          hexColor: 0xFFEF4444,
          qualificationLevel: 'Trainee',
          description: 'Trainee scaffolder',
        ),
        CardColor(
          id: 'gold',
          name: 'Gold',
          hexColor: 0xFFF59E0B,
          qualificationLevel: 'Advanced',
          description: 'Advanced scaffolder',
        ),
      ],
    ),
    CardScheme(
      id: 'fensa',
      name: 'FENSA',
      fullName: 'Fenestration Self-Assessment Scheme',
      description:
          'Competent person scheme for window/door installers to self-certify '
          'Building Regulations compliance.',
      applicableTrades: ['glazier'],
      colors: [
        CardColor(
          id: 'standard',
          name: 'FENSA Registered',
          hexColor: 0xFF0EA5E9,
          qualificationLevel: 'Registered Installer',
          description:
              'Registered to self-certify window/door installations',
        ),
      ],
    ),
  ];

  // ============================================
  // Lookup Helpers
  // ============================================

  /// Get a scheme by its ID.
  static CardScheme? getScheme(String schemeId) {
    try {
      return schemes.firstWhere((s) => s.id == schemeId);
    } catch (_) {
      return null;
    }
  }

  /// Get the list of colours available for a given scheme.
  static List<CardColor> getColorsForScheme(String schemeId) {
    return getScheme(schemeId)?.colors ?? [];
  }

  /// Get the qualification level for a given scheme + colour combination.
  static String? getQualificationLevel(String schemeId, String colorId) {
    final scheme = getScheme(schemeId);
    if (scheme == null) return null;
    try {
      return scheme.colors.firstWhere((c) => c.id == colorId).qualificationLevel;
    } catch (_) {
      return null;
    }
  }

  /// Get the primary trade mapped from a scheme.
  static String getMappedTrade(String schemeId) {
    final scheme = getScheme(schemeId);
    if (scheme == null) return '';
    return scheme.applicableTrades.first;
  }

  /// Get all schemes that apply to a given trade key.
  static List<CardScheme> getSchemesForTrade(String tradeKey) {
    return schemes
        .where((s) => s.applicableTrades.contains(tradeKey))
        .toList();
  }

  /// Whether Gas Safe is mandatory for the given trade.
  static bool isGasSafeMandatory(String tradeKey) {
    return tradeKey == 'central_heating' ||
        tradeKey == 'boiler_repair' ||
        tradeKey == 'gas_engineer';
  }

  /// Default validity period in years for a scheme.
  static int getValidityYears(String schemeId) {
    if (schemeId == 'gas_safe') return 1; // annual renewal
    return 5; // standard 5-year validity
  }
}

// ============================================
// Data Classes
// ============================================

class CardScheme {
  final String id;
  final String name;
  final String fullName;
  final String description;
  final List<String> applicableTrades;
  final List<CardColor> colors;

  const CardScheme({
    required this.id,
    required this.name,
    required this.fullName,
    required this.description,
    required this.applicableTrades,
    required this.colors,
  });
}

class CardColor {
  final String id;
  final String name;
  final int hexColor;
  final String qualificationLevel;
  final String description;

  const CardColor({
    required this.id,
    required this.name,
    required this.hexColor,
    required this.qualificationLevel,
    required this.description,
  });
}
