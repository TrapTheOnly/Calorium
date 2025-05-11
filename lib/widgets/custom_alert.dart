import 'package:flutter/material.dart';

class CustomAlert extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback onClose;

  const CustomAlert({
    Key? key,
    required this.title,
    this.message,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF101010),
        ),
        textAlign: TextAlign.center,
      ),
      content: message != null
          ? Text(
              message!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF29323F),
              ),
              textAlign: TextAlign.center,
            )
          : null,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}