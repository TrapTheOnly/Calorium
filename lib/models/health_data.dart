class HealthData {
  final double totalWorkoutTime; // in minutes
  final double totalCaloriesBurned; // in kcal
  final int totalSteps;
  final DateTime date;
  final List<WorkoutSession> workoutSessions;

  HealthData({
    required this.totalWorkoutTime,
    required this.totalCaloriesBurned,
    required this.totalSteps,
    required this.date,
    this.workoutSessions = const [],
  });

  HealthData.empty({DateTime? date})
      : totalWorkoutTime = 0,
        totalCaloriesBurned = 0,
        totalSteps = 0,
        date = date ?? DateTime.now(),
        workoutSessions = const [];

  Map<String, dynamic> toMap() {
    return {
      'totalWorkoutTime': totalWorkoutTime,
      'totalCaloriesBurned': totalCaloriesBurned,
      'totalSteps': totalSteps,
      'date': date.toIso8601String(),
      'workoutSessions': workoutSessions.map((session) => session.toMap()).toList(),
    };
  }

  factory HealthData.fromMap(Map<String, dynamic> map) {
    return HealthData(
      totalWorkoutTime: map['totalWorkoutTime'] ?? 0.0,
      totalCaloriesBurned: map['totalCaloriesBurned'] ?? 0.0,
      totalSteps: map['totalSteps'] ?? 0,
      date: DateTime.parse(map['date']),
      workoutSessions: List<WorkoutSession>.from(
        (map['workoutSessions'] ?? []).map((session) => WorkoutSession.fromMap(session))
      ),
    );
  }
}

class WorkoutSession {
  final String type;
  final DateTime startTime;
  final DateTime endTime;
  final double duration; // in minutes
  final double caloriesBurned;

  WorkoutSession({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.caloriesBurned,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': duration,
      'caloriesBurned': caloriesBurned,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      type: map['type'] ?? '',
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      duration: map['duration'] ?? 0.0,
      caloriesBurned: map['caloriesBurned'] ?? 0.0,
    );
  }
} 