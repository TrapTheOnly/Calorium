import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fasting_settings.dart';
import 'settings_service.dart';

class FastingStreak {
  const FastingStreak({required this.days, this.anchorDate});
  final int days;
  final DateTime? anchorDate;
}

class FastingService {
  static const String _fastingEnabledKey = 'fasting_enabled';
  static const String _legacyFastingStartKey = 'fasting_start_minutes';
  static const String _legacyFastingDurationKey = 'fasting_duration_minutes';
  static const String _eatingStartMinutesKey = 'fasting_eating_start_minutes';
  static const String _eatingDurationMinutesKey =
      'fasting_eating_duration_minutes';
  static const String _streakAnchorDateKey = 'fasting_streak_anchor';

  static const int _defaultEatingStartMinutes = 12 * 60; // 12:00 PM
  static const int _defaultEatingDurationMinutes = 8 * 60; // 8 hours

  static Future<FastingSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_fastingEnabledKey) ?? false;

    int? eatingStart = prefs.getInt(_eatingStartMinutesKey);
    int? eatingDuration = prefs.getInt(_eatingDurationMinutesKey);

    if (eatingDuration == null) {
      final legacyStart = prefs.getInt(_legacyFastingStartKey);
      final legacyDuration = prefs.getInt(_legacyFastingDurationKey);

      if (legacyStart != null && legacyDuration != null) {
        final converted = _convertLegacyConfig(
          fastingStart: legacyStart,
          fastingDuration: legacyDuration,
        );
        eatingStart = converted.item1;
        eatingDuration = converted.item2;
        await prefs.setInt(_eatingStartMinutesKey, eatingStart);
        await prefs.setInt(_eatingDurationMinutesKey, eatingDuration);
      }
    }

    eatingStart ??= _defaultEatingStartMinutes;
    eatingDuration ??= _defaultEatingDurationMinutes;

    final sanitizedEatingDuration =
        eatingDuration.clamp(60, FastingSettings.minutesPerDay - 60).toInt();

    return FastingSettings(
      enabled: enabled,
      eatingStartMinutes: eatingStart % FastingSettings.minutesPerDay,
      eatingDurationMinutes: sanitizedEatingDuration,
    );
  }

  static Future<void> saveSettings(FastingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fastingEnabledKey, settings.enabled);
    await prefs.setInt(
      _eatingStartMinutesKey,
      settings.eatingStartMinutes % FastingSettings.minutesPerDay,
    );
    await prefs.setInt(
      _eatingDurationMinutesKey,
      settings.eatingDurationMinutes
          .clamp(60, FastingSettings.minutesPerDay - 60)
          .toInt(),
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fastingEnabledKey, enabled);
    await SettingsService.setFastingNotificationsEnabled(enabled);
  }

  static Future<void> setEatingStartMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _eatingStartMinutesKey,
      minutes % FastingSettings.minutesPerDay,
    );
  }

  static Future<void> setEatingDurationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _eatingDurationMinutesKey,
      minutes.clamp(60, FastingSettings.minutesPerDay - 60).toInt(),
    );
  }

  static Future<FastingStatus> getStatus(DateTime reference) async {
    final settings = await getSettings();
    return settings.statusAt(reference);
  }

  static Future<bool> isEatingWindow(DateTime time) async {
    final settings = await getSettings();
    return settings.isWithinEatingWindow(time);
  }

  static Future<Duration> eatingTimeRemaining(DateTime reference) async {
    final settings = await getSettings();
    final status = settings.statusAt(reference);
    if (status.phase != FastingPhase.eating) {
      return Duration.zero;
    }
    return status.nextChange.difference(reference);
  }

  static List<String> fastingRecommendations() {
    return const [
      'Take a mindful pause before eating and drink a glass of water to re-align with your fasting window.',
      'Plan tomorrow\'s meals during your eating window to avoid unplanned snacks.',
      'Try a short walk or light activity to refocus your mind when cravings hit outside your eating window.',
      'Review your fasting schedule in Settings and adjust the start time so it better matches your lifestyle.',
    ];
  }

  static Future<void> initializeStreak(DateTime reference) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _toDateString(reference);
    await prefs.setString(_streakAnchorDateKey, today);
  }

  static Future<FastingStreak> getStreak(DateTime reference) async {
    final prefs = await SharedPreferences.getInstance();
    final anchorString = prefs.getString(_streakAnchorDateKey);
    if (anchorString == null) {
      return const FastingStreak(days: 0, anchorDate: null);
    }

    final today = DateTime(reference.year, reference.month, reference.day);
    final anchor = DateTime.tryParse(anchorString);
    if (anchor == null) {
      return const FastingStreak(days: 0, anchorDate: null);
    }

    final days = today.difference(anchor).inDays;
    return FastingStreak(days: days < 0 ? 0 : days, anchorDate: anchor);
  }

  static Future<void> recordFastingViolation(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final violationDate = _toDateString(timestamp);
    final existing = prefs.getString(_streakAnchorDateKey);
    DateTime? existingDate =
        existing != null ? DateTime.tryParse(existing) : null;
    final violationDateTime = DateTime.tryParse(violationDate);

    if (violationDateTime != null) {
      if (existingDate == null || violationDateTime.isAfter(existingDate)) {
        await prefs.setString(_streakAnchorDateKey, violationDate);
      }
    }
  }

  static Future<void> clearStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_streakAnchorDateKey);
  }

  static _Tuple<int, int> _convertLegacyConfig({
    required int fastingStart,
    required int fastingDuration,
  }) {
    final normalizedDuration =
        fastingDuration.clamp(60, FastingSettings.minutesPerDay - 60).toInt();
    final eatingDuration = FastingSettings.minutesPerDay - normalizedDuration;
    final eatingStart =
        (fastingStart - eatingDuration) % FastingSettings.minutesPerDay;
    return (_Tuple<int, int>(eatingStart, eatingDuration));
  }

  static String _toDateString(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }
}

class _Tuple<T1, T2> {
  const _Tuple(this.item1, this.item2);
  final T1 item1;
  final T2 item2;
}
