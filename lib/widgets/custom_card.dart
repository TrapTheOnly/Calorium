 import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double elevation;
  final BorderRadius? borderRadius;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.onTap,
    this.elevation = 0,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}