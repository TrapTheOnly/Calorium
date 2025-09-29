import 'package:intl/intl.dart';
import '../models/fasting_advice.dart';
import 'fasting_service.dart';

class FastingAdvisor {
  static Future<FastingAdvice?> evaluateMeal({
    required DateTime loggedAt,
    String? mealName,
  }) async {
    final settings = await FastingService.getSettings();
    if (!settings.enabled || !settings.isValid) {
      return null;
    }

    if (settings.isWithinEatingWindow(loggedAt)) {
      return null;
    }

    final status = settings.statusAt(loggedAt);
    final formatter = DateFormat.jm();
    final loggedLabel = formatter.format(loggedAt);
    final nextEatingLabel = formatter.format(status.nextChange);

    final displayName =
        mealName?.trim().isNotEmpty == true ? mealName!.trim() : 'This meal';
    final body =
        StringBuffer()
          ..write(
            '$displayName was logged at $loggedLabel, outside your planned eating window.',
          )
          ..write(' Your next eating window opens at $nextEatingLabel.');

    final tips = FastingService.fastingRecommendations();
    final index = loggedAt.millisecondsSinceEpoch.abs() % tips.length;
    final tip = tips[index];

    await FastingService.recordFastingViolation(loggedAt);

    return FastingAdvice(
      title: 'Keep your fasting rhythm',
      body: body.toString(),
      tip: tip,
    );
  }
}
