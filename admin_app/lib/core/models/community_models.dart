class ForumThread {
  final String id;
  final String classNodeId;
  final String? subjectId;
  final String title;
  final String authorId;
  final bool isPinned;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int postCount;

  ForumThread({
    required this.id,
    required this.classNodeId,
    this.subjectId,
    required this.title,
    required this.authorId,
    this.isPinned = false,
    this.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.postCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    return ForumThread(
      id: json['id'] as String,
      classNodeId: json['class_node_id'] as String,
      subjectId: json['subject_id'] as String?,
      title: json['title'] as String,
      authorId: json['author_id'] as String,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      isLocked: (json['is_locked'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

class ForumPost {
  final String id;
  final String threadId;
  final String authorId;
  final String content;
  final bool flagged;
  final String? flagReason;
  final String moderationStatus;
  final DateTime createdAt;

  ForumPost({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.content,
    this.flagged = false,
    this.flagReason,
    this.moderationStatus = 'visible',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      flagged: (json['flagged'] as bool?) ?? false,
      flagReason: json['flag_reason'] as String?,
      moderationStatus: json['moderation_status'] as String? ?? 'visible',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class WhatsappCommunity {
  final String id;
  final String classNodeId;
  final String inviteLink;
  final int memberCountEstimate;
  final bool isActive;
  final DateTime createdAt;

  WhatsappCommunity({
    required this.id,
    required this.classNodeId,
    required this.inviteLink,
    required this.memberCountEstimate,
    required this.isActive,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WhatsappCommunity.fromJson(Map<String, dynamic> json) {
    return WhatsappCommunity(
      id: json['id'] as String,
      classNodeId: json['class_node_id'] as String,
      inviteLink: json['invite_link'] as String,
      memberCountEstimate: (json['member_count_estimate'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class SupportTicket {
  final String id;
  final String accountId;
  final String category;
  final String subject;
  final String description;
  final String requesterType;
  final String status;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.accountId,
    required this.category,
    required this.subject,
    required this.description,
    required this.requesterType,
    required this.status,
    this.assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      category: json['category'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      requesterType: json['requester_type'] as String,
      status: json['status'] as String? ?? 'ouvert',
      assignedTo: json['assigned_to'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
