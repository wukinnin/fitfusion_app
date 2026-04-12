import 'package:supabase_flutter/supabase_flutter.dart';

import 'service_exception.dart';

class AuthUser {
  final String id;
  final String email;
  final bool isEmailVerified;

  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });
}

class SignupResult {
  final String email;
  final String type;

  const SignupResult({
    required this.email,
    this.type = 'signup',
  });
}

enum LoginDestination { home, verify }

class LoginResult {
  final LoginDestination destination;
  final String? email;
  final String? type;

  const LoginResult.home()
      : destination = LoginDestination.home,
        email = null,
        type = null;

  const LoginResult.verify({
    required this.email,
    this.type = 'signup',
  }) : destination = LoginDestination.verify;
}

enum VerifyDestination { login, resetPassword }

class VerifyResult {
  final VerifyDestination destination;
  final String? email;

  const VerifyResult.login()
      : destination = VerifyDestination.login,
        email = null;

  const VerifyResult.resetPassword({
    required this.email,
  }) : destination = VerifyDestination.resetPassword;
}

class ChangeEmailResult {
  final bool requiresVerification;
  final String email;
  final String type;

  const ChangeEmailResult({
    required this.requiresVerification,
    required this.email,
    this.type = 'email_change',
  });
}

abstract class AuthService {
  AuthUser? get currentUser;
  bool get hasActiveSession;

  Future<SignupResult> signUp({
    required String username,
    required String email,
    required String password,
  });

  Future<VerifyResult> verifyEmail({
    required String email,
    required String code,
    required String type,
  });

  Future<void> resendVerificationCode({
    required String email,
    required String type,
  });

  Future<LoginResult> login({
    required String identifier,
    required String password,
  });

  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword(String newPassword);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> changeUsername({
    required String currentPassword,
    required String newUsername,
  });
  Future<ChangeEmailResult> changeEmail({
    required String currentPassword,
    required String newEmail,
  });
  Future<void> deleteAccount(String currentPassword);
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email!,
      isEmailVerified: user.emailConfirmedAt != null,
    );
  }

  @override
  bool get hasActiveSession => _client.auth.currentSession != null;

  @override
  Future<SignupResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final emailExists = await _client.rpc(
        'check_email_exists',
        params: {'p_email': email},
      ) as bool;

      if (emailExists) {
        final rows = await _client
            .from('users')
            .select('is_email_verified')
            .eq('email', email)
            .limit(1);

        if (rows.isNotEmpty && rows[0]['is_email_verified'] == false) {
          await _client.auth.resend(type: OtpType.signup, email: email);
          return SignupResult(email: email);
        }

        throw const AppServiceException('Email is already taken');
      }

      final existingEmail = await _client.rpc(
        'get_email_by_username',
        params: {'p_username': username},
      );
      if (existingEmail != null) {
        throw const AppServiceException('Username is already taken');
      }

      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      return SignupResult(email: email);
    } on AppServiceException {
      rethrow;
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<VerifyResult> verifyEmail({
    required String email,
    required String code,
    required String type,
  }) async {
    try {
      final otpType = type == 'recovery' ? OtpType.recovery : OtpType.signup;

      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: otpType,
      );

      if (type == 'signup') {
        final userId = _client.auth.currentUser?.id;
        if (userId != null) {
          await _client
              .from('users')
              .update({'is_email_verified': true})
              .eq('id', userId);
        }
        await _client.auth.signOut();
        return const VerifyResult.login();
      }

      if (type == 'recovery') {
        return VerifyResult.resetPassword(email: email);
      }

      await _client.auth.signOut();
      return const VerifyResult.login();
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('Verification failed');
    }
  }

  @override
  Future<void> resendVerificationCode({
    required String email,
    required String type,
  }) async {
    try {
      if (type == 'recovery') {
        await _client.auth.resetPasswordForEmail(email);
        return;
      }
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('Failed to resend code');
    }
  }

  @override
  Future<LoginResult> login({
    required String identifier,
    required String password,
  }) async {
    try {
      String email = identifier;
      if (!identifier.contains('@')) {
        final resolved = await _client.rpc(
          'get_email_by_username',
          params: {'p_username': identifier},
        );
        if (resolved == null) {
          throw const AppServiceException('Username not found');
        }
        email = resolved as String;
      }

      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final rows = await _client
            .from('users')
            .select('is_email_verified')
            .eq('id', userId)
            .limit(1);
        if (rows.isNotEmpty && rows[0]['is_email_verified'] == false) {
          await _client.auth.signOut();
          await _client.auth.resend(type: OtpType.signup, email: email);
          return LoginResult.verify(email: email);
        }
      }

      return const LoginResult.home();
    } on AppServiceException {
      rethrow;
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> resetPassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (email == null) {
      throw const AppServiceException('No authenticated user');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> changeUsername({
    required String currentPassword,
    required String newUsername,
  }) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppServiceException('No authenticated user');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      final existingEmail = await _client.rpc(
        'get_email_by_username',
        params: {'p_username': newUsername},
      );
      if (existingEmail != null) {
        throw const AppServiceException('Username is already taken');
      }

      await _client.from('users').update({'username': newUsername}).eq('id', user.id);
      await _client.auth.updateUser(
        UserAttributes(data: {'username': newUsername}),
      );
    } on AppServiceException {
      rethrow;
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<ChangeEmailResult> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (email == null) {
      throw const AppServiceException('No authenticated user');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(email: newEmail));
      return ChangeEmailResult(
        requiresVerification: false,
        email: newEmail,
      );
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> deleteAccount(String currentPassword) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppServiceException('No authenticated user');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      final response = await _client.functions.invoke(
        'delete-player',
        body: {'user_id': user.id},
      );

      if (response.data != null && response.data['error'] != null) {
        throw AppServiceException(response.data['error'].toString());
      }

      await _client.auth.signOut();
    } on AppServiceException {
      rethrow;
    } on AuthException catch (e) {
      throw AppServiceException(e.message);
    } catch (_) {
      throw const AppServiceException('An unexpected error occurred');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
