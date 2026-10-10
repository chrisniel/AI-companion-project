import 'package:meta/meta.dart';

/// Base domain exception for AI Companion client errors.
@immutable
abstract class CompanionException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const CompanionException(this.message, {this.code, this.cause});

  @override
  String toString() =>
      code != null ? 'CompanionException[$code]: $message' : 'CompanionException: $message';
}

/// Error indicating failure to communicate with the Local AI Runtime.
class ConnectionException extends CompanionException {
  const ConnectionException(super.message, {super.code, super.cause});
}

/// Error indicating an authentication or pairing credential rejection.
class AuthenticationException extends CompanionException {
  const AuthenticationException(super.message, {super.code, super.cause});
}

/// Error indicating an invalid or unprocessable domain state.
class DomainValidationException extends CompanionException {
  const DomainValidationException(super.message, {super.code, super.cause});
}
