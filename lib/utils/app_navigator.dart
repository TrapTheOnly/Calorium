import 'package:flutter/material.dart';
import '../screens/main_shell.dart';

/// App-wide navigation handles for notification taps and deep links.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();

void openInsightsTab() {
  mainShellKey.currentState?.selectTab(2);
}

void openTodayTab() {
  mainShellKey.currentState?.selectTab(0);
}
