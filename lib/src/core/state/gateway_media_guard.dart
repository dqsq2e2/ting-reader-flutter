bool isPrematureGatewayMediaCompletion({
  required double positionSeconds,
  required double expectedDurationSeconds,
}) {
  if (!expectedDurationSeconds.isFinite || expectedDurationSeconds <= 0) {
    return false;
  }

  final normalizedPosition = positionSeconds.isFinite
      ? positionSeconds.clamp(0, expectedDurationSeconds).toDouble()
      : 0.0;
  final completionTolerance =
      (expectedDurationSeconds * 0.03).clamp(5.0, 15.0).toDouble();
  return expectedDurationSeconds - normalizedPosition > completionTolerance;
}

double gatewayMediaResumePosition({
  required double positionSeconds,
  required double furthestPositionSeconds,
  required double expectedDurationSeconds,
}) {
  final current = positionSeconds.isFinite ? positionSeconds : 0.0;
  final furthest =
      furthestPositionSeconds.isFinite ? furthestPositionSeconds : 0.0;
  final candidate = current > furthest ? current : furthest;
  if (!expectedDurationSeconds.isFinite || expectedDurationSeconds <= 0) {
    return candidate < 0 ? 0 : candidate;
  }
  return candidate.clamp(0, expectedDurationSeconds).toDouble();
}
