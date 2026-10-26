import 'dart:async';

import '../../../core/http/api_failure.dart';

import 'package:flutter/services.dart';

({String outcome, String reason}) failureOutcome(Object? error) {
  if (error is TimeoutException) {
    return (outcome: 'timeout', reason: 'deadline');
  }
  if (error is PlatformException) {
    if ({
      'CANCELLED',
      'USER_CANCELLED',
      'AbortError',
      'cancelled',
    }.contains(error.code)) {
      return (outcome: 'cancelled', reason: 'disposed');
    }
    if ({
      'PERMISSION_DENIED',
      'NotAllowedError',
      'SecurityError',
    }.contains(error.code)) {
      return (outcome: 'rejected', reason: 'permission_denied');
    }
  }
  final status = error is ApiFailure ? error.status : null;
  if (status == 401 || status == 403) {
    return (outcome: 'rejected', reason: 'permission_denied');
  }
  if (status == 409) return (outcome: 'rejected', reason: 'conflict');
  if (status != null && status >= 400 && status < 500) {
    return (outcome: 'rejected', reason: 'invalid');
  }
  return (outcome: 'failed', reason: status == null ? 'network' : 'dependency');
}
