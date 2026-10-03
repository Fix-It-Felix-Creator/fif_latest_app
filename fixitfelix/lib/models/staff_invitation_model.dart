import 'package:equatable/equatable.dart';

/// Status of staff invitation
enum InvitationStatus { pending, accepted, rejected, cancelled }

/// Staff invitation model
class StaffInvitationModel extends Equatable {
  final String id;
  final String inviterId; // Tradesman who sent the invitation
  final String inviterName;
  final String inviterEmail;
  final String? inviterProfileImage;
  final String inviteeId; // User being invited
  final String inviteeName;
  final String inviteeEmail;
  final String? inviteeProfileImage;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseMessage;

  const StaffInvitationModel({
    required this.id,
    required this.inviterId,
    required this.inviterName,
    required this.inviterEmail,
    this.inviterProfileImage,
    required this.inviteeId,
    required this.inviteeName,
    required this.inviteeEmail,
    this.inviteeProfileImage,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.responseMessage,
  });

  bool get isPending => status == InvitationStatus.pending;
  bool get isAccepted => status == InvitationStatus.accepted;
  bool get isRejected => status == InvitationStatus.rejected;
  bool get isCancelled => status == InvitationStatus.cancelled;

  StaffInvitationModel copyWith({
    String? id,
    String? inviterId,
    String? inviterName,
    String? inviterEmail,
    String? inviterProfileImage,
    String? inviteeId,
    String? inviteeName,
    String? inviteeEmail,
    String? inviteeProfileImage,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? responseMessage,
  }) {
    return StaffInvitationModel(
      id: id ?? this.id,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      inviterProfileImage: inviterProfileImage ?? this.inviterProfileImage,
      inviteeId: inviteeId ?? this.inviteeId,
      inviteeName: inviteeName ?? this.inviteeName,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      inviteeProfileImage: inviteeProfileImage ?? this.inviteeProfileImage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'inviterProfileImage': inviterProfileImage,
      'inviteeId': inviteeId,
      'inviteeName': inviteeName,
      'inviteeEmail': inviteeEmail,
      'inviteeProfileImage': inviteeProfileImage,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'responseMessage': responseMessage,
    };
  }

  factory StaffInvitationModel.fromJson(Map<String, dynamic> json) {
    return StaffInvitationModel(
      id: json['id'] ?? '',
      inviterId: json['inviterId'] ?? '',
      inviterName: json['inviterName'] ?? '',
      inviterEmail: json['inviterEmail'] ?? '',
      inviterProfileImage: json['inviterProfileImage'],
      inviteeId: json['inviteeId'] ?? '',
      inviteeName: json['inviteeName'] ?? '',
      inviteeEmail: json['inviteeEmail'] ?? '',
      inviteeProfileImage: json['inviteeProfileImage'],
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvitationStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
      responseMessage: json['responseMessage'],
    );
  }

  @override
  List<Object?> get props => [
    id,
    inviterId,
    inviterName,
    inviterEmail,
    inviterProfileImage,
    inviteeId,
    inviteeName,
    inviteeEmail,
    inviteeProfileImage,
    status,
    createdAt,
    respondedAt,
    responseMessage,
  ];
}

/// Status of staff member
enum StaffMemberStatus { pending, active, inactive, removed }

/// Staff member model (for accepted invitations)
class StaffMemberModel extends Equatable {
  final String id;
  final String odwnerId; // Tradesman who owns the staff
  final String memberId; // Staff member user ID
  final String name;
  final String email;
  final String? profileImage;
  final DateTime joinedAt;
  final StaffMemberStatus status;
  final List<String>? trade; // Staff member's trade types

  const StaffMemberModel({
    required this.id,
    required this.odwnerId,
    required this.memberId,
    required this.name,
    required this.email,
    this.profileImage,
    required this.joinedAt,
    this.status = StaffMemberStatus.active,
    this.trade,
  });

  bool get isActive => status == StaffMemberStatus.active;
  bool get isPending => status == StaffMemberStatus.pending;
  bool get isInactive => status == StaffMemberStatus.inactive;
  bool get isRemoved => status == StaffMemberStatus.removed;

  StaffMemberModel copyWith({
    String? id,
    String? odwnerId,
    String? memberId,
    String? name,
    String? email,
    String? profileImage,
    DateTime? joinedAt,
    StaffMemberStatus? status,
    List<String>? trade,
  }) {
    return StaffMemberModel(
      id: id ?? this.id,
      odwnerId: odwnerId ?? this.odwnerId,
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      trade: trade ?? this.trade,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': odwnerId,
      'memberId': memberId,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'joinedAt': joinedAt.toIso8601String(),
      'status': status.name,
      'trade': trade,
    };
  }

  factory StaffMemberModel.fromJson(Map<String, dynamic> json) {
    // Handle both old 'isActive' format and new 'status' format
    StaffMemberStatus memberStatus;
    if (json['status'] != null) {
      memberStatus = StaffMemberStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StaffMemberStatus.active,
      );
    } else {
      // Legacy support: convert isActive boolean to status
      memberStatus = (json['isActive'] ?? true)
          ? StaffMemberStatus.active
          : StaffMemberStatus.inactive;
    }

    return StaffMemberModel(
      id: json['id'] ?? '',
      odwnerId: json['ownerId'] ?? '',
      memberId: json['memberId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      status: memberStatus,
      trade: json['trade'] != null ? List<String>.from(json['trade']) : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    odwnerId,
    memberId,
    name,
    email,
    profileImage,
    joinedAt,
    status,
    trade,
  ];
}
