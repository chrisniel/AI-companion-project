import 'package:meta/meta.dart';

/// DTO representing the public health probe response from GET /api/v1/health.
@immutable
class HealthResponse {
  final String status;

  const HealthResponse({required this.status});

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    final statusVal = json['status'];
    if (statusVal is! String) {
      throw FormatException('HealthResponse: status must be a string, got $statusVal');
    }
    return HealthResponse(status: statusVal);
  }

  Map<String, dynamic> toJson() => {'status': status};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthResponse && runtimeType == other.runtimeType && status == other.status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'HealthResponse(status: $status)';
}
