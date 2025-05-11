# Calorie Tracker - Flutter Edition

A Flutter implementation of the Calorie Tracker app, supporting Material You design principles and 120Hz animations.

## Features

- Track daily calorie intake
- Add simple and compound foods
- View nutrition information (calories, protein, fat, carbs)
- Edit and delete food entries
- Historical data tracking
- Material You design
- Optimized for 120Hz displays

## Getting Started

1. Make sure you have Flutter installed (v3.0+)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## Project Structure
lib/
├── models/ # Data models
├── screens/ # App screens
├── services/ # Database and APIs
├── utils/ # Helper utilities
├── widgets/ # Reusable widgets
└── main.dart # Entry point


## Performance Optimizations

This app is optimized for high refresh rate displays (90Hz/120Hz):

- Smooth animations
- Optimized transition durations
- Hardware acceleration
- Efficient state management

## Database Schema

The app uses SQLite with the following tables:

- foods: Store food items
- logs: Track daily food consumption
- components: Link compound foods to their ingredients