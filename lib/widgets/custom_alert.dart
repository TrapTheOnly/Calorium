import 'package:flutter/material.dart';

enum AlertType { success, error, info, warning }

class CustomAlert extends StatelessWidget {
  final String title;
  final String? message;
  final AlertType type;
  final VoidCallback? onClose;
  final String? actionButtonText;
  final VoidCallback? onActionPressed;

  const CustomAlert({
    Key? key,
    required this.title,
    this.message,
    this.type = AlertType.info,
    this.onClose,
    this.actionButtonText,
    this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getTypeColor(context).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(),
              color: _getTypeColor(context),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: message != null
          ? Text(
              message!,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            )
          : null,
      actions: [
        Column(
          children: [
            if (onActionPressed != null && actionButtonText != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getTypeColor(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    actionButtonText!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  onActionPressed != null ? 'Cancel' : 'OK',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getTypeColor(BuildContext context) {
    switch (type) {
      case AlertType.success:
        return Colors.green;
      case AlertType.error:
        return Colors.red;
      case AlertType.warning:
        return Colors.orange;
      case AlertType.info:
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
      default:
        return Icons.info;
    }
  }
}

// Helper methods for easy usage
class AlertHelper {
  static void showSuccessAlert(
    BuildContext context, {
    required String title,
    String? message,
    String? actionButtonText,
    VoidCallback? onActionPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => CustomAlert(
        title: title,
        message: message,
        type: AlertType.success,
        actionButtonText: actionButtonText,
        onActionPressed: onActionPressed,
      ),
    );
  }

  static void showErrorAlert(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    showDialog(
      context: context,
      builder: (context) => CustomAlert(
        title: title,
        message: message,
        type: AlertType.error,
      ),
    );
  }

  static void showInfoAlert(
    BuildContext context, {
    required String title,
    String? message,
    String? actionButtonText,
    VoidCallback? onActionPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => CustomAlert(
        title: title,
        message: message,
        type: AlertType.info,
        actionButtonText: actionButtonText,
        onActionPressed: onActionPressed,
      ),
    );
  }
}