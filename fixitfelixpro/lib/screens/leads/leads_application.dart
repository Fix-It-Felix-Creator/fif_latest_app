import 'package:flutter/foundation.dart';

/// Who is applying.
enum LeadsApplicantType { solo, business }

/// How far a plan lets a tradesperson be seen.
///
/// The numbers are the seeded `serviceRadiusMiles` on each plan: Standard 0,
/// Pro 100, Advance unlimited. They live here as a mirror for the UI to read
/// while nothing is wired — the database stays the source of truth.
enum LeadsPlanTier { standard, pro, advance }

extension LeadsPlanTierX on LeadsPlanTier {
  String get label => switch (this) {
        LeadsPlanTier.standard => 'Standard',
        LeadsPlanTier.pro => 'Pro',
        LeadsPlanTier.advance => 'Advance',
      };

  /// Business accounts are an Advance feature.
  bool get allowsBusiness => this == LeadsPlanTier.advance;
}

/// A plan, as the database describes it.
///
/// The radius used to be hardcoded per tier here — 0, 100, unlimited — which
/// meant the app and `subscription_plans` each had their own opinion of what a
/// plan allows. They agreed right up until somebody changed the table, and
/// then the app quietly enforced the old numbers. The server is the only place
/// that decides now; this carries the answer.
class LeadsPlan {
  const LeadsPlan({required this.tier, required this.radiusMiles});

  const LeadsPlan.standard()
      : tier = LeadsPlanTier.standard,
        radiusMiles = 0;

  final LeadsPlanTier tier;

  /// Miles. -1 means unlimited; 0 means this plan is not listed at all.
  final int radiusMiles;

  String get label => tier.label;
  bool get allowsBusiness => tier.allowsBusiness;

  /// Whether live leads actually arrive on this plan.
  ///
  /// Applying is open to everyone — being sent work is not. A Standard
  /// tradesperson can be approved and ready, and the day the plan allows it
  /// the leads start.
  bool get receivesLeads => radiusMiles != 0;

  bool get isUnlimited => radiusMiles == -1;

  String get radiusLabel {
    if (radiusMiles == 0) return 'Not visible for live leads';
    if (radiusMiles == -1) return 'UK wide';
    return 'Up to $radiusMiles miles';
  }
}

/// How hard a missing registration should bite.
enum LeadsGateLevel {
  /// The work is an offence without it. The application cannot be sent.
  blocking,

  /// Not illegal without, but insurers and customers treat it as table
  /// stakes. Collected and shown, never blocked — a scaffolder without a
  /// CISRS card is still a scaffolder, and refusing them would be us
  /// inventing a law.
  advisory,
}

/// Trades that need a scheme registration, and how badly.
///
/// The split matters. Gas work without Gas Safe registration is a criminal
/// offence under the Gas Safety (Installation and Use) Regulations 1998;
/// scaffolding without a CISRS card is merely unusual. Treating those the same
/// would either wave through illegal work or lock out legitimate trades, and
/// both are worse than asking the right question.
const leadsGatedServices = <String, LeadsGate>{
  // ---- blocking: illegal without ----
  'gas_engineer': LeadsGate(
    scheme: 'Gas Safe Register',
    hint: 'Your 6 or 7 digit Gas Safe number',
    why: 'Gas work may only be carried out by a Gas Safe registered engineer. '
        'It is a criminal offence otherwise.',
    level: LeadsGateLevel.blocking,
  ),
  'boiler_repair': LeadsGate(
    scheme: 'Gas Safe Register',
    hint: 'Your 6 or 7 digit Gas Safe number',
    why: 'Working on a gas boiler requires Gas Safe registration by law.',
    level: LeadsGateLevel.blocking,
  ),
  'central_heating': LeadsGate(
    scheme: 'Gas Safe Register',
    hint: 'Your 6 or 7 digit Gas Safe number',
    why: 'Gas-fired heating work requires Gas Safe registration by law.',
    level: LeadsGateLevel.blocking,
  ),
  'electrician': LeadsGate(
    scheme: 'NICEIC, NAPIT, ELECSA or STROMA',
    hint: 'Your scheme registration number',
    why: 'Notifiable electrical work falls under Part P of the building '
        'regulations and must be done by a registered installer.',
    level: LeadsGateLevel.blocking,
  ),
  'hvac_technician': LeadsGate(
    scheme: 'F-Gas certification',
    hint: 'Your F-Gas company or personal certificate number',
    why: 'Handling refrigerant requires F-Gas certification under the '
        'Fluorinated Greenhouse Gases Regulations.',
    level: LeadsGateLevel.blocking,
  ),

  // ---- advisory: expected, not required ----
  'glazier': LeadsGate(
    scheme: 'FENSA or CERTASS',
    hint: 'Your installer registration number',
    why: 'Replacement windows are notifiable under Part L. Registered '
        'installers can self-certify instead of using building control.',
    level: LeadsGateLevel.advisory,
  ),
  'scaffolder': LeadsGate(
    scheme: 'CISRS card',
    hint: 'Your CISRS card number',
    why: 'The industry standard for scaffolding competence. Most commercial '
        'sites will not let you on without it.',
    level: LeadsGateLevel.advisory,
  ),
  'tree_surgeon': LeadsGate(
    scheme: 'NPTC or LANTRA',
    hint: 'Your certificate number',
    why: 'Chainsaw and aerial rescue tickets. Insurers usually require them '
        'and customers ask.',
    level: LeadsGateLevel.advisory,
  ),
  'welder': LeadsGate(
    scheme: 'CSWIP or BS EN ISO 9606',
    hint: 'Your coding certificate number',
    why: 'Coded welding is required for structural and pressure work.',
    level: LeadsGateLevel.advisory,
  ),
  'mechanic': LeadsGate(
    scheme: 'DVSA or F-Gas',
    hint: 'MOT tester number, or F-Gas number for air-con work',
    why: 'MOT testing requires DVSA approval, and air-conditioning work '
        'requires F-Gas certification.',
    level: LeadsGateLevel.advisory,
  ),
  'roofer': LeadsGate(
    scheme: 'CompetentRoofer',
    hint: 'Your scheme registration number',
    why: 'Lets you self-certify roofing work under Part L rather than going '
        'through building control.',
    level: LeadsGateLevel.advisory,
  ),
};

/// Trades that routinely take waste away from a customer's property.
///
/// Carrying someone else's waste without being a registered carrier is an
/// offence under the Controlled Waste Regulations, and it catches far more
/// trades than the scheme registrations above do — which is exactly why it is
/// the one people forget. Asked once, for the whole application, rather than
/// per trade.
const leadsWasteCarrierTrades = <String>{
  'tree_surgeon',
  'builder',
  'landscaper',
  'gardener',
  'handyman',
  'cleaner',
  'scaffolder',
  'roofer',
  'labourer',
};

class LeadsGate {
  const LeadsGate({
    required this.scheme,
    required this.hint,
    required this.why,
    required this.level,
  });

  final String scheme;
  final String hint;
  final String why;
  final LeadsGateLevel level;

  bool get isBlocking => level == LeadsGateLevel.blocking;
}

/// Which photo of a document this is.
enum LeadsDocumentSlot { front, back, selfie }

/// What somebody can prove themselves with.
enum LeadsDocumentType { passport, drivingLicence, idCard }

extension LeadsDocumentTypeX on LeadsDocumentType {
  String get wire => switch (this) {
        LeadsDocumentType.passport => 'passport',
        LeadsDocumentType.drivingLicence => 'driving_licence',
        LeadsDocumentType.idCard => 'id_card',
      };

  String get label => switch (this) {
        LeadsDocumentType.passport => 'Passport',
        LeadsDocumentType.drivingLicence => 'Driving licence',
        LeadsDocumentType.idCard => 'National ID card',
      };

  /// A passport photo page carries everything; a licence and an ID card do
  /// not, so both sides are asked for.
  List<LeadsDocumentSlot> get slots => switch (this) {
        LeadsDocumentType.passport => const [LeadsDocumentSlot.front],
        _ => const [LeadsDocumentSlot.front, LeadsDocumentSlot.back],
      };
}

/// Everything the application collects, as one mutable draft.
///
/// A plain ChangeNotifier rather than a bloc: this is a form that lives for
/// the length of one flow and is thrown away, and every screen in it writes to
/// the same object. Wiring it to Supabase later replaces the submit step, not
/// this.
class LeadsApplicationDraft extends ChangeNotifier {
  LeadsApplicationDraft({required this.plan});

  /// Rebuilds a draft from an application that was rejected, withdrawn or
  /// superseded.
  ///
  /// Re-applying should not mean retyping. Somebody turned down over one wrong
  /// digit in a Gas Safe number will not fill six screens in again, and asking
  /// them to is how a fixable rejection becomes a lost tradesperson.
  factory LeadsApplicationDraft.from(
    dynamic previous, {
    required LeadsPlan plan,
  }) {
    final d = LeadsApplicationDraft(plan: plan);
    if (previous == null) return d;
    d.applicantType =
        previous.isSolo as bool ? LeadsApplicantType.solo : LeadsApplicantType.business;
    d.services.addAll((previous.services as List).cast<String>());
    d.registrations
        .addAll((previous.registrations as Map).cast<String, String>());
    d.movesWaste = previous.movesWaste as bool?;
    d.wasteCarrierNumber = (previous.wasteCarrierNumber as String?) ?? '';
    d.baseAddress = previous.baseAddress as String?;
    d.latitude = previous.baseLatitude as double?;
    d.longitude = previous.baseLongitude as double?;
    d.workingDays
      ..clear()
      ..addAll((previous.workingDays as List).cast<int>());
    d.takesEmergencies = previous.takesEmergencies as bool;
    d.hasNoInsurance = !(previous.hasOwnInsurance as bool);
    d.insurer = (previous.insurer as String?) ?? '';
    d.policyNumber = (previous.policyNumber as String?) ?? '';
    d.coverAmount = (previous.coverAmount as String?) ?? '';
    d.policyExpiry = previous.policyExpiresAt as DateTime?;
    d.headline = previous.headline as String;
    d.about = previous.about as String;
    d.yearsExperience = previous.yearsExperience as int?;
    return d;
  }

  /// The plan the applicant is on today. Decides what the flow explains, and
  /// whether Business is offered at all — never whether they may apply.
  final LeadsPlan plan;

  LeadsApplicantType? applicantType;

  /// Service ids from the Pro app's own trade list. Solo keeps one; a business
  /// may hold many.
  final Set<String> services = {};

  /// Registration numbers for the gated services above, keyed by service id.
  final Map<String, String> registrations = {};

  /// Environment Agency waste carrier registration, if they move waste.
  String wasteCarrierNumber = '';
  bool? movesWaste;

  // Coverage
  String? baseAddress;
  double? latitude;
  double? longitude;
  bool takesEmergencies = false;
  final Set<int> workingDays = {1, 2, 3, 4, 5};

  // Insurance
  String insurer = '';
  String policyNumber = '';
  String coverAmount = '';
  DateTime? policyExpiry;
  bool hasNoInsurance = false;

  // Identity
  LeadsDocumentType? documentType;

  /// Local file paths, not uploaded yet — the upload happens on submit, so
  /// abandoning the flow leaves nothing in the bucket to clean up.
  final Map<LeadsDocumentSlot, String> documentPaths = {};
  String? selfiePath;

  // Public profile
  String headline = '';
  String about = '';
  int? yearsExperience;

  void touch() => notifyListeners();

  void setApplicantType(LeadsApplicantType type) {
    applicantType = type;
    // A solo tradesperson keeps one service. Dropping the extras here rather
    // than at the next screen means going back and changing your mind cannot
    // leave a solo application holding five trades.
    if (type == LeadsApplicantType.solo && services.length > 1) {
      final first = services.first;
      services
        ..clear()
        ..add(first);
      registrations.removeWhere((k, _) => k != first);
    }
    notifyListeners();
  }

  bool get isSolo => applicantType == LeadsApplicantType.solo;

  int get maxServices => isSolo ? 1 : 99;

  void toggleService(String id) {
    if (services.contains(id)) {
      services.remove(id);
      registrations.remove(id);
    } else {
      if (isSolo) {
        services.clear();
        registrations.clear();
      }
      services.add(id);
    }
    notifyListeners();
  }

  /// Gated services picked, in no particular order.
  List<String> get gatedServices =>
      [for (final id in services) if (leadsGatedServices.containsKey(id)) id];

  /// Gated services whose registration is required by law and still blank.
  ///
  /// The only ones that can stop a submission. An advisory scheme left empty
  /// is a gap on the application, not a barrier — the reviewer sees it and
  /// decides.
  List<String> get missingRequiredRegistrations => [
        for (final id in gatedServices)
          if (leadsGatedServices[id]!.isBlocking &&
              (registrations[id] ?? '').trim().isEmpty)
            id,
      ];

  /// Advisory schemes left blank. Surfaced, never enforced.
  List<String> get missingAdvisoryRegistrations => [
        for (final id in gatedServices)
          if (!leadsGatedServices[id]!.isBlocking &&
              (registrations[id] ?? '').trim().isEmpty)
            id,
      ];

  /// Whether any selected trade routinely carries waste away.
  bool get mayMoveWaste =>
      services.any(leadsWasteCarrierTrades.contains);

  /// Whether the flow needs its registrations step at all.
  ///
  /// Most trades are not gated, and a step that would only ever say "nothing
  /// to do here" is a step worth not showing.
  bool get needsRegistrations => gatedServices.isNotEmpty || mayMoveWaste;

  bool get servicesComplete => services.isNotEmpty;

  /// Only the legally required numbers gate the step. Waste carrying gates on
  /// the ANSWER, not the number: "no, I do not remove waste" is a complete
  /// answer and a common one.
  bool get registrationsComplete =>
      missingRequiredRegistrations.isEmpty &&
      (!mayMoveWaste ||
          movesWaste == false ||
          (movesWaste == true && wasteCarrierNumber.trim().isNotEmpty));

  // ---- step numbering ------------------------------------------------------
  //
  // Derived rather than hardcoded per screen, because the registrations step
  // appears and disappears as trades are ticked. A screen that knows it is
  // "step 4" is wrong the moment someone goes back and unticks Gas Engineer.

  int get _shift => needsRegistrations ? 1 : 0;

  int get totalSteps => 6 + _shift;
  int get stepAccountType => 1;
  int get stepServices => 2;
  int get stepRegistrations => 3;
  int get stepCoverage => 3 + _shift;
  int get stepInsurance => 4 + _shift;
  int get stepIdentity => 5 + _shift;
  int get stepAbout => 6 + _shift;

  void setDocumentType(LeadsDocumentType type) {
    if (documentType == type) return;
    documentType = type;
    documentPaths.removeWhere((slot, _) => !type.slots.contains(slot));
    notifyListeners();
  }

  void setDocument(LeadsDocumentSlot slot, String? path) {
    if (slot == LeadsDocumentSlot.selfie) {
      selfiePath = path;
    } else if (path == null) {
      documentPaths.remove(slot);
    } else {
      documentPaths[slot] = path;
    }
    notifyListeners();
  }

  List<LeadsDocumentSlot> get missingDocumentSlots => [
        for (final slot in documentType?.slots ?? const <LeadsDocumentSlot>[])
          if (!documentPaths.containsKey(slot)) slot,
      ];

  bool get identityComplete =>
      documentType != null &&
      missingDocumentSlots.isEmpty &&
      selfiePath != null;

  /// A postcode already known, to open the address search pre-filled.
  ///
  /// Only from a previous answer — there is nothing else on the draft to guess
  /// from, and a wrong guess is worse than an empty box.
  String? get postcodeGuess {
    final address = baseAddress;
    if (address == null) return null;
    final match = RegExp(
      r'([A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2})',
      caseSensitive: false,
    ).firstMatch(address);
    return match?.group(1);
  }

  bool get coverageComplete =>
      (baseAddress ?? '').trim().isNotEmpty && workingDays.isNotEmpty;

  bool get insuranceComplete =>
      hasNoInsurance ||
      (insurer.trim().isNotEmpty &&
          policyNumber.trim().isNotEmpty &&
          policyExpiry != null);

  bool get aboutComplete => headline.trim().isNotEmpty && about.trim().length >= 40;

  bool get readyToSubmit =>
      applicantType != null &&
      servicesComplete &&
      // Still checked here even though the registrations step enforces it.
      // servicesComplete was loosened when that step was split out, and this
      // is the gate on the final submit — a legally gated trade reaching
      // review with no scheme number is the one thing the step exists to
      // prevent.
      registrationsComplete &&
      coverageComplete &&
      insuranceComplete &&
      identityComplete &&
      aboutComplete;
}
