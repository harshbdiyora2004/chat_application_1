class UserModel {
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String bio;
  final String? profilePictureUrl;

  UserModel({
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.bio,
    this.profilePictureUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      bio: map['bio'] ?? '',
      profilePictureUrl: map['profilePictureUrl'],
    );
  }
}
