class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code, this.retryAfter});
  final String message;
  final int? status;
  final String? code;
  final Duration? retryAfter;
  @override
  String toString() => message;
}
