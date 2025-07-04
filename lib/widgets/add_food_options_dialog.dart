import 'package:flutter/material.dart';
import '../screens/ai_quick_add_screen.dart';
import '../screens/inventory_screen.dart';

class AddFoodOptionsDialog extends StatelessWidget {
  final String date;
  final String title;
  final String subtitle;
  final VoidCallback? onComplete;

  const AddFoodOptionsDialog({
    super.key,
    required this.date,
    this.title = 'Add Food Entry',
    this.subtitle = 'Choose how you want to add food to your log',
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing based on screen dimensions
    final isTablet = screenWidth > 600;
    final dialogWidth = isTablet ? 420.0 : screenWidth * 0.92;
    final maxDialogHeight = screenHeight * 0.6;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
          minHeight: 240,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with improved spacing
              _buildHeader(context, isTablet),
              
              SizedBox(height: isTablet ? 24 : 20),
              
              // Option Cards with improved design
              _buildModernOptionCard(
                context: context,
                title: 'AI Quick Scan',
                subtitle: 'Take a photo and let AI analyze the food',
                icon: Icons.camera_alt_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
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
                isTablet: isTablet,
              ),
              
              SizedBox(height: isTablet ? 14 : 12),
              
              _buildModernOptionCard(
                context: context,
                title: 'From Inventory',
                subtitle: 'Select from your saved foods or search database',
                icon: Icons.inventory_2_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
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
                isTablet: isTablet,
              ),
              
              SizedBox(height: isTablet ? 20 : 16),
              
              // Cancel button with improved design
              _buildCancelButton(context, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Column(
      children: [
        // Title with responsive font size
        Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isTablet ? 8 : 6),
        
        // Subtitle with improved styling
        Text(
          subtitle,
          style: TextStyle(
            fontSize: isTablet ? 14 : 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModernOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 18 : 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Modern icon container without glow
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: isTablet ? 22 : 20,
                ),
              ),
              
              SizedBox(width: isTablet ? 16 : 14),
              
              // Improved text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: isTablet ? 4 : 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Modern arrow with better styling
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: isTablet ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: isTablet ? 12 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: isTablet ? 14 : 13,
            fontWeight: FontWeight.w500,
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
      barrierDismissible: true,
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