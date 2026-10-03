import '../../models/trade_requirement.dart';

/// UK Trade Qualification Requirements
///
/// Static mapping of trade keys to required documents based on UK law.
/// Each tradesman must upload specific qualifications, certifications,
/// and insurance documents depending on their trade.
class UkTradeRequirements {
  UkTradeRequirements._();

  /// Construction trades that require CSCS and CITB
  static const List<String> constructionTrades = [
    'builder',
    'roofer',
    'plasterer',
    'carpenter',
    'tiler',
    'glazier',
    'scaffolder',
    'welder',
    'kitchen_fitter',
    'labourer',
  ];

  /// All trade requirement definitions
  static const List<TradeRequirement> allRequirements = [
    // ──────────────────────────────────────────────
    // Universal requirements (all 22 trades)
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'public_liability_insurance',
      name: 'Public Liability Insurance',
      description:
          'Valid public liability insurance certificate covering your trade work. '
          'Minimum coverage of \u00a31 million is typically required.',
      category: RequirementCategory.legal,
      isMandatory: true,
      applicableTrades: null, // all trades
    ),
    TradeRequirement(
      id: 'nvq_svq_apprenticeship',
      name: 'NVQ/SVQ or Apprenticeship Certificate',
      description:
          'National Vocational Qualification, Scottish Vocational Qualification, '
          'or completed apprenticeship certificate in your trade.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: null, // all trades
    ),

    // ──────────────────────────────────────────────
    // Construction trades (CSCS + CITB)
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'cscs_card',
      name: 'CSCS Card',
      description:
          'Construction Skills Certification Scheme card proving competence '
          'to work on construction sites.',
      category: RequirementCategory.safety,
      isMandatory: true,
      applicableTrades: constructionTrades,
    ),
    TradeRequirement(
      id: 'citb_health_safety',
      name: 'CITB Health & Safety Test Certificate',
      description:
          'Certificate from the Construction Industry Training Board '
          'health and safety test.',
      category: RequirementCategory.safety,
      isMandatory: true,
      applicableTrades: constructionTrades,
    ),

    // ──────────────────────────────────────────────
    // Electrician
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'electrician_level3_diploma',
      name: 'Level 3 Diploma in Electrical Installations',
      description:
          'City & Guilds or equivalent Level 3 Diploma in Electrical Installations '
          '(Buildings and Structures).',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['electrician'],
    ),
    TradeRequirement(
      id: 'electrician_18th_edition',
      name: '18th Edition Wiring Regulations Certificate',
      description:
          'BS 7671:2018 Requirements for Electrical Installations '
          '(18th Edition IET Wiring Regulations) certificate.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['electrician'],
    ),
    TradeRequirement(
      id: 'electrician_niceic',
      name: 'NICEIC Registration',
      description:
          'National Inspection Council for Electrical Installation Contracting '
          'registration certificate.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: true,
      applicableTrades: ['electrician'],
    ),

    // ──────────────────────────────────────────────
    // Central Heating & Boiler Repair (Gas Safe)
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'gas_safe_registration',
      name: 'Gas Safe Registration',
      description:
          'Valid Gas Safe Register ID card. It is a legal requirement to be '
          'on the Gas Safe Register to work on gas appliances in the UK.',
      category: RequirementCategory.legal,
      isMandatory: true,
      applicableTrades: ['central_heating', 'boiler_repair', 'gas_engineer'],
    ),

    // ──────────────────────────────────────────────
    // Plumber
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'plumber_city_guilds',
      name: 'City & Guilds Level 2+ Diploma in Plumbing',
      description:
          'City & Guilds Level 2 or above Diploma in Plumbing and Heating, '
          'or equivalent NVQ.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['plumber'],
    ),

    // ──────────────────────────────────────────────
    // Tree Surgeon
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'tree_surgeon_nptc',
      name: 'NPTC Certificate of Competence',
      description:
          'National Proficiency Tests Council certificate of competence '
          'in chainsaw and tree work operations.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['tree_surgeon'],
    ),

    // ──────────────────────────────────────────────
    // Locksmith
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'locksmith_dbs',
      name: 'DBS Check Certificate',
      description:
          'Disclosure and Barring Service check certificate. Required due to '
          'the security-sensitive nature of locksmith work.',
      category: RequirementCategory.legal,
      isMandatory: true,
      applicableTrades: ['locksmith'],
    ),

    // ──────────────────────────────────────────────
    // Glazier
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'glazier_competent_person_scheme',
      name: 'Competent Person Scheme Registration (FENSA/CERTASS)',
      description:
          'Registration with an approved competent person scheme for window/door '
          'installation to self-certify Building Regulations compliance.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: true,
      applicableTrades: ['glazier'],
    ),

    // ──────────────────────────────────────────────
    // HVAC Technician
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'fgas_personnel_qualification',
      name: 'F-Gas Personnel Qualification',
      description:
          'Individual qualification for handling fluorinated refrigerant gases. '
          'Legal requirement under UK F-Gas regulations.',
      category: RequirementCategory.legal,
      isMandatory: true,
      applicableTrades: ['hvac_technician'],
    ),
    TradeRequirement(
      id: 'fgas_company_certification',
      name: 'F-Gas Company Certification',
      description:
          'Company certification to service stationary refrigeration/AC/heat pump '
          'equipment. Required by law for businesses (including sole traders).',
      category: RequirementCategory.legal,
      isMandatory: true,
      applicableTrades: ['hvac_technician'],
    ),

    // ──────────────────────────────────────────────
    // Scaffolder
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'scaffolder_cisrs_card',
      name: 'CISRS Scaffolding Card',
      description:
          'Construction Industry Scaffolders Record Scheme card proving '
          'scaffolding competence.',
      category: RequirementCategory.safety,
      isMandatory: true,
      applicableTrades: ['scaffolder'],
    ),

    // ──────────────────────────────────────────────
    // Welder
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'welder_qualification',
      name: 'Welding Qualification Certificate',
      description:
          'Industry welding qualification/coding certificate '
          '(e.g., BS EN ISO 9606). Commonly required by contract.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['welder'],
    ),

    // ──────────────────────────────────────────────
    // Hairdresser
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'hairdresser_nvq_level2',
      name: 'NVQ/SVQ Level 2 in Hairdressing',
      description:
          'City & Guilds or VTCT Level 2 Diploma in Hairdressing. '
          'The industry-standard entry-level qualification for practising hairdressers.',
      category: RequirementCategory.qualification,
      isMandatory: true,
      applicableTrades: ['hairdresser'],
    ),
    TradeRequirement(
      id: 'hairdresser_hygiene_cert',
      name: 'Health & Hygiene Certificate',
      description:
          'Certificate in infection control and hygiene practices for '
          'hairdressing and barbering. Required by most local authorities.',
      category: RequirementCategory.safety,
      isMandatory: true,
      applicableTrades: ['hairdresser'],
    ),

    // ──────────────────────────────────────────────
    // Optional requirements
    // ──────────────────────────────────────────────
    TradeRequirement(
      id: 'mechanic_mot_tester',
      name: 'MOT Tester Certification',
      description:
          'DVSA-authorised MOT tester certification. Optional but adds credibility.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: false,
      applicableTrades: ['mechanic'],
    ),
    TradeRequirement(
      id: 'handyman_trade_cert',
      name: 'Relevant Trade Certificate',
      description:
          'Any relevant trade certificate or qualification that demonstrates '
          'competence in your areas of work.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: false,
      applicableTrades: ['handyman'],
    ),
    TradeRequirement(
      id: 'pesticide_certificate',
      name: 'Pesticide Application Certificate (PA1/PA6)',
      description:
          'Certificate of competence for the safe use of pesticides. '
          'Required if you apply professional pesticides.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: false,
      applicableTrades: ['gardener', 'landscaper'],
    ),
    TradeRequirement(
      id: 'painter_cscs',
      name: 'CSCS Card',
      description:
          'Construction Skills Certification Scheme card. Optional for painters '
          'but recommended for site work.',
      category: RequirementCategory.safety,
      isMandatory: false,
      applicableTrades: ['painter'],
    ),
    TradeRequirement(
      id: 'cleaner_dbs',
      name: 'DBS Check Certificate',
      description:
          'Disclosure and Barring Service check certificate. Recommended for '
          'cleaners who work in private homes.',
      category: RequirementCategory.legal,
      isMandatory: false,
      applicableTrades: ['cleaner', 'window_cleaner'],
    ),
    TradeRequirement(
      id: 'hairdresser_nvq_level3',
      name: 'NVQ/SVQ Level 3 in Hairdressing',
      description:
          'Advanced diploma covering colour correction, creative cutting, '
          'and salon management. Recommended for senior stylists.',
      category: RequirementCategory.qualification,
      isMandatory: false,
      applicableTrades: ['hairdresser'],
    ),
    TradeRequirement(
      id: 'hairdresser_colour_specialist',
      name: 'Colour Specialist Certification',
      description:
          'Advanced certification in hair colouring techniques (e.g. VTCT Level 3 '
          'Award in Colouring). Adds credibility for specialist colour services.',
      category: RequirementCategory.tradeSpecific,
      isMandatory: false,
      applicableTrades: ['hairdresser'],
    ),
    TradeRequirement(
      id: 'employers_liability_insurance',
      name: 'Employers Liability Insurance',
      description:
          'Legally required if you employ anyone (min \u00a35m cover). '
          'Mandatory as soon as you become an employer.',
      category: RequirementCategory.legal,
      isMandatory: false,
      applicableTrades: null, // all trades
    ),
    TradeRequirement(
      id: 'waste_carrier_registration',
      name: 'Waste Carrier Registration',
      description:
          'Environment Agency waste carrier registration. Mandatory if '
          'transporting controlled waste (especially construction/demolition waste).',
      category: RequirementCategory.legal,
      isMandatory: false,
      applicableTrades: [
        'builder',
        'roofer',
        'plasterer',
        'carpenter',
        'tiler',
        'kitchen_fitter',
        'glazier',
        'landscaper',
        'labourer',
      ],
    ),
    TradeRequirement(
      id: 'work_at_height_competence',
      name: 'Work at Height Training Certificate',
      description:
          'Competence certificate for working at height. HSE requires '
          'work at height to be carried out by competent people.',
      category: RequirementCategory.safety,
      isMandatory: false,
      applicableTrades: [
        'roofer',
        'scaffolder',
        'glazier',
        'painter',
        'builder',
        'tree_surgeon',
        'window_cleaner',
        'labourer',
      ],
    ),
  ];

  /// Get requirements for a specific trade key
  static List<TradeRequirement> getRequirementsForTrade(String tradeKey) {
    return allRequirements.where((req) {
      if (req.applicableTrades == null) return true; // universal
      return req.applicableTrades!.contains(tradeKey);
    }).toList();
  }

  /// Get mandatory requirements for a specific trade key
  static List<TradeRequirement> getMandatoryRequirements(String tradeKey) {
    return getRequirementsForTrade(tradeKey)
        .where((req) => req.isMandatory)
        .toList();
  }

  /// Get optional requirements for a specific trade key
  static List<TradeRequirement> getOptionalRequirements(String tradeKey) {
    return getRequirementsForTrade(tradeKey)
        .where((req) => !req.isMandatory)
        .toList();
  }

  /// Get requirements grouped by category for a trade
  static Map<RequirementCategory, List<TradeRequirement>>
      getGroupedRequirements(String tradeKey) {
    final requirements = getRequirementsForTrade(tradeKey);
    final grouped = <RequirementCategory, List<TradeRequirement>>{};

    for (final category in RequirementCategory.values) {
      final categoryReqs =
          requirements.where((r) => r.category == category).toList();
      if (categoryReqs.isNotEmpty) {
        grouped[category] = categoryReqs;
      }
    }

    return grouped;
  }
}
