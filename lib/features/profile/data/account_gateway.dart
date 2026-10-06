import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../settings/data/user_settings_repository.dart';

/// Account changes the profile and settings screens can make.
///
/// A narrow seam so those screens can be tested without Firebase.
abstract interface class AccountGateway {
  /// False for Google and Apple accounts, which have no password.
  bool get canChangePassword;

  /// `Google` or `Apple` when [canChangePassword] is false.
  String? get externalProviderLabel;

  Future<void> updatePhone(AppUser user, String phone);

  Future<void> requestEmailUpdate(String email, {String? currentPassword});

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  Future<void> deleteAccount({String? currentPassword});
}

class FirebaseAccountGateway implements AccountGateway {
  FirebaseAccountGateway({required this._auth, required this._settings});

  final AuthRepository _auth;
  final UserSettingsRepository _settings;

  @override
  bool get canChangePassword => _auth.canChangePassword;

  @override
  String? get externalProviderLabel => _auth.externalProviderLabel;

  @override
  Future<void> updatePhone(AppUser user, String phone) {
    return _auth.updateProfile(user.copyWith(phoneNumber: phone.trim()));
  }

  @override
  Future<void> requestEmailUpdate(String email, {String? currentPassword}) {
    return _auth.requestEmailUpdate(email, currentPassword: currentPassword);
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _auth.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _settings.removeCurrentDeviceToken();
    } on Object {
      // A stale token is better than being unable to sign out.
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount({String? currentPassword}) {
    return _auth.deleteAccount(currentPassword: currentPassword);
  }
}

final accountGatewayProvider = Provider<AccountGateway>(
  (ref) => FirebaseAccountGateway(
    auth: ref.watch(authRepositoryProvider),
    settings: ref.watch(userSettingsRepositoryProvider),
  ),
);
