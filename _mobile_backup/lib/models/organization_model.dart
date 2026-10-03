class OrganizationModel {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final int memberCount;

  OrganizationModel({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.memberCount,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      ownerId: json['owner_id'] ?? '',
      memberCount: json['member_count'] ?? 1,
    );
  }
}

class MemberModel {
  final String id;
  final String organizationId;
  final String userId;
  final String userFullName;
  final String userEmail;
  final String? userPhone;
  final String relationshipLabel; // Wife, Husband, Brother, Cousin, Friend, etc.
  final String role; // OWNER, ADMIN, MEMBER, READ_ONLY
  final String isActive;

  MemberModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    this.userPhone,
    required this.relationshipLabel,
    required this.role,
    required this.isActive,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      userId: json['user_id'] ?? '',
      userFullName: json['user_full_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      userPhone: json['user_phone'],
      relationshipLabel: json['relationship_label'] ?? 'Member',
      role: json['role'] ?? 'MEMBER',
      isActive: json['is_active'] ?? 'ACTIVE',
    );
  }
}
