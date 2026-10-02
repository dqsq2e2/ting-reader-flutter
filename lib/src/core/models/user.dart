import 'dart:convert';

import '_helpers.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.role,
    this.usesDefaultAdminCredentials = false,
    this.createdAt,
    this.librariesAccessible = const [],
    this.booksAccessible = const [],
  });

  final String id;
  final String username;
  final String role;
  final bool usesDefaultAdminCredentials;
  final String? createdAt;
  final List<String> librariesAccessible;
  final List<String> booksAccessible;

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: readString(json, 'id') ?? '',
      username: readString(json, 'username') ?? '',
      role: readString(json, 'role') ?? 'user',
      usesDefaultAdminCredentials:
          json['uses_default_admin_credentials'] == true,
      createdAt: readString(json, 'created_at'),
      librariesAccessible: readStringList(json['libraries_accessible']),
      booksAccessible: readStringList(json['books_accessible']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        'uses_default_admin_credentials': usesDefaultAdminCredentials,
        if (createdAt != null) 'created_at': createdAt,
        'libraries_accessible': librariesAccessible,
        'books_accessible': booksAccessible,
      };

  String encode() => jsonEncode(toJson());
}
