import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/ai_quick_add_screen.dart';
import '../screens/inventory_screen.dart';

class AddFoodOptionsDialog extends StatelessWidget {
  static Future<void> show(
    BuildContext context, {
    required String date,
    String title = 'Quick Add',
    String subtitle = 'Pick how you want to add food',
    VoidCallback? onComplete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AddFoodOptionsDialog(
              date: date,
              title: title,
              subtitle: subtitle,
              onComplete: onComplete,
            ),
          ),
        ),
      ),
    );
  }

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
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    final isTablet = size.width > 600;
    final dialogWidth = isTablet ? 420.0 : size.width * 0.92;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: 560,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactHeader(title: title, subtitle: subtitle, date: date),
              // Scrollable content to avoid overflow on small screens
              SingleChildScrollView(
                primary: false,
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 16,
                  isTablet ? 12 : 10,
                  isTablet ? 20 : 16,
                  isTablet ? 8 : 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OptionCard(
                      title: 'AI Quick Scan',
                      subtitle:
                          'Snap a photo and let AI log nutrition for you instantly.',
                      icon: Icons.bolt_rounded,
                      gradientStart: theme.colorScheme.primary,
                      gradientEnd:
                          theme.colorScheme.primary.withOpacity(0.75),
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
                    SizedBox(height: isTablet ? 10 : 8),
                    _OptionCard(
                      title: 'From Inventory',
                      subtitle:
                          'Browse your saved foods or search the database.',
                      icon: Icons.inventory_2_rounded,
                      gradientStart: theme.colorScheme.secondary,
                      gradientEnd:
                          theme.colorScheme.secondary.withOpacity(0.75),
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
                    SizedBox(height: isTablet ? 10 : 8),
                    _CancelButton(isTablet: isTablet),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.date,
  });

  final String title;
  final String subtitle;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? prettyDate;
    try {
      prettyDate = DateFormat.MMMEd().format(DateTime.parse(date));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_outlined,
              color: theme.colorScheme.onPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (prettyDate != null)
                  Text(
                    prettyDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
    required this.isTablet,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback onTap;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: gradientStart.withOpacity(0.15),
        highlightColor: gradientStart.withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 14 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart.withOpacity(0.18),
                gradientEnd.withOpacity(0.14),
              ],
            ),
            border: Border.all(
              color: gradientStart.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientStart.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimary,
                  size: isTablet ? 20 : 18,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        height: 1.25,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: gradientStart,
                  size: isTablet ? 18 : 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.isTablet});

  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: TextStyle(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text('Cancel'),
      ),
    );
  }
}
