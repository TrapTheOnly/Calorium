import 'package:flutter/material.dart';

enum FastingPhase { eating, fasting }

class FastingStatus {
  const FastingStatus({
    required this.enabled,
    required this.phase,
    required this.phaseStart,
    required this.phaseEnd,
    required this.reference,
  });

  final bool enabled;
  final FastingPhase phase;
  final DateTime phaseStart;
  final DateTime phaseEnd;
  final DateTime reference;

  DateTime get nextChange => phaseEnd;

  Duration get timeUntilChange => phaseEnd.difference(reference);

  Duration get phaseDuration => phaseEnd.difference(phaseStart);

  double get progress {
    final total = phaseDuration.inSeconds;
    if (total <= 0) return 1;
    final elapsed = reference.difference(phaseStart).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class FastingSettings {
  const FastingSettings({
    required this.enabled,
    required this.eatingStartMinutes,
    required this.eatingDurationMinutes,
  });

  final bool enabled;
  final int eatingStartMinutes;
  final int eatingDurationMinutes;

  static const int minutesPerDay = 24 * 60;

  factory FastingSettings.disabled() {
    return const FastingSettings(
      enabled: false,
      eatingStartMinutes: 12 * 60, // Noon
      eatingDurationMinutes: 8 * 60, // Eight-hour eating window
    );
  }

  TimeOfDay get eatingStartTime {
    final hours = eatingStartMinutes ~/ 60;
    final minutes = eatingStartMinutes % 60;
    return TimeOfDay(hour: hours % 24, minute: minutes % 60);
  }

  TimeOfDay get fastingStartTime {
    final minutes = fastingStartMinutes;
    final hours = minutes ~/ 60;
    return TimeOfDay(hour: hours % 24, minute: minutes % 60);
  }

  Duration get eatingDuration => Duration(minutes: eatingDurationMinutes);

  int get fastingStartMinutes =>
      (eatingStartMinutes + eatingDurationMinutes) % minutesPerDay;

  Duration get fastingDuration =>
      Duration(minutes: minutesPerDay - eatingDurationMinutes);

  bool get isValid =>
      enabled &&
      eatingDurationMinutes > 0 &&
      eatingDurationMinutes < minutesPerDay;

  FastingStatus statusAt(DateTime reference) {
    if (!isValid) {
      final now = DateTime(reference.year, reference.month, reference.day);
      return FastingStatus(
        enabled: false,
        phase: FastingPhase.eating,
        phaseStart: now,
        phaseEnd: now.add(const Duration(days: 1)),
        reference: reference,
      );
    }

    final cycleEatingStart = _mostRecentEatingStart(reference);
    final eatingStart = cycleEatingStart;
    final eatingEnd = eatingStart.add(eatingDuration);

    if (reference.isBefore(eatingEnd)) {
      return FastingStatus(
        enabled: true,
        phase: FastingPhase.eating,
        phaseStart: eatingStart,
        phaseEnd: eatingEnd,
        reference: reference,
      );
    }

    final nextEatingStart = eatingStart.add(const Duration(days: 1));

    return FastingStatus(
      enabled: true,
      phase: FastingPhase.fasting,
      phaseStart: eatingEnd,
      phaseEnd: nextEatingStart,
      reference: reference,
    );
  }

  bool isWithinEatingWindow(DateTime reference) {
    if (!isValid) return true;
    return statusAt(reference).phase == FastingPhase.eating;
  }

  DateTime _mostRecentEatingStart(DateTime reference) {
    final dayStart = DateTime(reference.year, reference.month, reference.day);
    final candidate = dayStart.add(Duration(minutes: eatingStartMinutes));

    if (reference.isBefore(candidate)) {
      return candidate.subtract(const Duration(days: 1));
    }
    return candidate;
  }

  FastingSettings copyWith({
    bool? enabled,
    int? eatingStartMinutes,
    int? eatingDurationMinutes,
  }) {
    return FastingSettings(
      enabled: enabled ?? this.enabled,
      eatingStartMinutes: eatingStartMinutes ?? this.eatingStartMinutes,
      eatingDurationMinutes:
          eatingDurationMinutes ?? this.eatingDurationMinutes,
    );
  }
}
