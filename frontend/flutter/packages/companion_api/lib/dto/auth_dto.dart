import 'package:meta/meta.dart';

/// DTO representing the response from POST /api/v1/auth/verify.
@immutable
class AuthVerifyResponse {
  final bool authenticated;
  final String tokenType;
  final String message;

  const AuthVerifyResponse({
    this.authenticated = true,
    this.tokenType = 'Bearer',
    this.message = 'Token is valid and authenticated.',
  });

  factory AuthVerifyResponse.fromJson(Map<String, dynamic> json) {
    final authVal = json['authenticated'];
    if (authVal != null && authVal is! bool) {
      throw FormatException('AuthVerifyResponse: authenticated must be a bool, got $authVal');
    }

    final tokenTypeVal = json['token_type'];
    if (tokenTypeVal != null && tokenTypeVal is! String) {
      throw FormatException('AuthVerifyResponse: token_type must be a string, got $tokenTypeVal');
    }

    final msgVal = json['message'];
    if (msgVal != null && msgVal is! String) {
      throw FormatException('AuthVerifyResponse: message must be a string, got $msgVal');
    }

    return AuthVerifyResponse(
      authenticated: authVal as bool? ?? true,
      tokenType: tokenTypeVal as String? ?? 'Bearer',
      message: msgVal as String? ?? 'Token is valid and authenticated.',
    );
  }

  Map<String, dynamic> toJson() => {
        'authenticated': authenticated,
        'token_type': tokenType,
        'message': message,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthVerifyResponse &&
          runtimeType == other.runtimeType &&
          authenticated == other.authenticated &&
          tokenType == other.tokenType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(authenticated, tokenType, message);

  @override
  String toString() =>
      'AuthVerifyResponse(authenticated: $authenticated, tokenType: $tokenType, message: $message)';
}
