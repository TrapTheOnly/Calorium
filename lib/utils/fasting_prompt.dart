import 'package:flutter/material.dart';
import '../services/fasting_advisor.dart';
import '../models/fasting_advice.dart';
import '../widgets/custom_alert.dart';

class FastingPrompt {
  static Future<void> showIfNeeded(
    BuildContext context, {
    required DateTime loggedAt,
    String? mealName,
  }) async {
    final FastingAdvice? advice = await FastingAdvisor.evaluateMeal(
      loggedAt: loggedAt,
      mealName: mealName,
    );
    if (advice == null) return;

    final message = StringBuffer(advice.body);
    if (advice.tip.isNotEmpty) {
      message
        ..writeln('\n')
        ..write('Tip: ${advice.tip}');
    }

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => CustomAlert(
            title: advice.title,
            message: message.toString(),
            type: AlertType.info,
          ),
    );
  }
}
