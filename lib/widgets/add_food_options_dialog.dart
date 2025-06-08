import 'package:flutter/material.dart';
import '../screens/ai_quick_add_screen.dart';
import '../screens/inventory_screen.dart';

class AddFoodOptionsDialog extends StatelessWidget {
  final String date;
  final String title;
  final String subtitle;
  final VoidCallback? onComplete;

  const AddFoodOptionsDialog({
    Key? key,
    required this.date,
    this.title = 'Add Food Entry',
    this.subtitle = 'Choose how you want to add food to your log',
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Option Cards
            _buildOptionCard(
              context: context,
              title: 'AI Quick Scan',
              subtitle: 'Take a photo and let AI analyze the food',
              icon: Icons.camera_alt_rounded,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AiQuickAddScreen(date: date),
                  ),
                );
                onComplete?.call();
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildOptionCard(
              context: context,
              title: 'From Inventory',
              subtitle: 'Select from your saved foods or search database',
              icon: Icons.inventory_2_rounded,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InventoryScreen(date: date),
                  ),
                );
                onComplete?.call();
              },
            ),
            
            const SizedBox(height: 24),
            
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container with dynamic theme colors
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Static method to show the dialog
  static Future<void> show(
    BuildContext context, {
    required String date,
    String title = 'Add Food Entry',
    String subtitle = 'Choose how you want to add food to your log',
    VoidCallback? onComplete,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AddFoodOptionsDialog(
          date: date,
          title: title,
          subtitle: subtitle,
          onComplete: onComplete,
        );
      },
    );
  }
} 