// lib/features/auth/data/models/user_model.dart

class UserModel {
  final String? id;
  final String? phoneNumber;
  final String? name;
  final String? avatar;
  final String? about;
  final bool? isOnline;
  final bool? isNewUser;
  final String? fcmToken;
  final String? currentChatWith;
  final List<dynamic>? contacts;
  final List<dynamic>? blockedUsers;
  final String? lastSeen;
  final String? createdAt;
  final NotificationSettingsModel? notificationSettings;

  UserModel({
    this.id,
    this.phoneNumber,
    this.name,
    this.avatar,
    this.about,
    this.isOnline,
    this.isNewUser,
    this.fcmToken,
    this.currentChatWith,
    this.contacts,
    this.blockedUsers,
    this.lastSeen,
    this.createdAt,
    this.notificationSettings,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'],
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      avatar: json['avatar'] ?? '', // ✅ Default empty string
      about: json['about'] ?? '', // ✅ Default empty string
      isOnline: json['isOnline'] ?? false,
      isNewUser: json['isNewUser'] ?? false,
      fcmToken: json['fcmToken'],
      currentChatWith: json['currentChatWith'],
      contacts: json['contacts'] ?? [], // ✅ Default empty list
      blockedUsers: json['blockedUsers'] ?? [], // ✅ Default empty list
      lastSeen: json['lastSeen'],
      createdAt: json['createdAt'],
      notificationSettings: json['notificationSettings'] != null
          ? NotificationSettingsModel.fromJson(json['notificationSettings'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'phoneNumber': phoneNumber,
      'name': name,
      'avatar': avatar,
      'about': about,
      'isOnline': isOnline,
      'isNewUser': isNewUser,
      'fcmToken': fcmToken,
      'currentChatWith': currentChatWith,
      'contacts': contacts,
      'blockedUsers': blockedUsers,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
      'notificationSettings': notificationSettings?.toJson(),
    };
  }
}

// lib/features/auth/data/models/notification_settings_model.dart

class NotificationSettingsModel {
  final bool messageNotifications;
  final bool callNotifications;
  final bool groupNotifications;
  final bool sound;
  final bool vibrate;

  NotificationSettingsModel({
    required this.messageNotifications,
    required this.callNotifications,
    required this.groupNotifications,
    required this.sound,
    required this.vibrate,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      messageNotifications: json['messageNotifications'] ?? true,
      callNotifications: json['callNotifications'] ?? true,
      groupNotifications: json['groupNotifications'] ?? true,
      sound: json['sound'] ?? true,
      vibrate: json['vibrate'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageNotifications': messageNotifications,
      'callNotifications': callNotifications,
      'groupNotifications': groupNotifications,
      'sound': sound,
      'vibrate': vibrate,
    };
  }
}