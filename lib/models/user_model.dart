class UserModel {
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String bio;
  final String? profilePictureBase64;

  UserModel({
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.bio,
    this.profilePictureBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'profilePictureBase64': profilePictureBase64,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      bio: map['bio'] ?? '',
      profilePictureBase64: map['profilePictureBase64'],
    );
  }
}
