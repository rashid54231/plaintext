enum Role { manager, student }

class User {
  final String? id;
  final String name;
  final String email;
  final String password;
  final Role role;
  final String? phone;
  final String? classCode;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.phone,
    this.classCode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role.name,
      'phone': phone ?? '',
      'class_code': classCode,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      role: map['role'] == 'manager' ? Role.manager : Role.student,
      phone: map['phone'] as String?,
      classCode: map['class_code'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    Role? role,
    String? phone,
    String? classCode,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      classCode: classCode ?? this.classCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isManager => role == Role.manager;
  bool get isStudent => role == Role.student;
}
