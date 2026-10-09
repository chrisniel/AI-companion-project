/// Exception thrown by [CompanionClient] when an HTTP or API protocol error occurs.
class CompanionApiException implements Exception {
  final int statusCode;
  final String? code;
  final String message;
  final dynamic details;

  const CompanionApiException({
    required this.statusCode,
    this.code,
    required this.message,
    this.details,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isUnprocessable => statusCode == 422;
  bool get isUnavailable => statusCode == 503;

  @override
  String toString() =>
      'CompanionApiException(status: $statusCode, code: $code, message: "$message")';
}
