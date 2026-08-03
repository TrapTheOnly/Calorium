import 'package:flutter/material.dart';
import '../screens/ai_quick_add_screen.dart';
import '../screens/inventory_screen.dart';
import '../theme/app_theme.dart';

/// An "Add entry" FAB that, when tapped, reveals two actions above it:
/// "Using AI" (brand accent) and "From inventory" (a distinct accent).
///
/// The expanded state (scrim + actions) is rendered in the *root overlay* so the
/// dimming covers the entire window — including the app bar and the bottom
/// navigation bar — instead of just the page body. Because the menu lives in an
/// overlay that is removed the instant an action is chosen, it can never "leak"
/// on top of the next screen during a page transition.
///
/// Place it directly as `Scaffold.floatingActionButton`.
class AddEntrySpeedDial extends StatefulWidget {
  const AddEntrySpeedDial({super.key, required this.date, this.onComplete});

  final String date;
  final VoidCallback? onComplete;

  @override
  State<AddEntrySpeedDial> createState() => _AddEntrySpeedDialState();
}

class _AddEntrySpeedDialState extends State<AddEntrySpeedDial>
    with SingleTickerProviderStateMixin {
  final GlobalKey _fabKey = GlobalKey();
  late final AnimationController _controller;
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (_isOpen) return;
    final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (box == null || overlay == null) return;

    final fabOffset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final fabSize = box.size;

    _entry = OverlayEntry(
      builder: (ctx) => _SpeedDialMenu(
        controller: _controller,
        fabOffset: fabOffset,
        fabSize: fabSize,
        onClose: _close,
        onAi: _openAi,
        onInventory: _openInventory,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _controller.forward();
    setState(() {}); // hide the underlying FAB while the menu is open
  }

  Future<void> _close() async {
    if (!_isOpen) return;
    await _controller.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _dismissImmediately() {
    _controller.value = 0;
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  Future<void> _openAi() async {
    _dismissImmediately();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiQuickAddScreen(date: widget.date),
      ),
    );
    widget.onComplete?.call();
  }

  Future<void> _openInventory() async {
    _dismissImmediately();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryScreen(date: widget.date),
      ),
    );
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the FAB in the tree (so its position is known) but invisible while
    // the overlay shows an identical, non-dimmed FAB on top of the scrim.
    return Opacity(
      opacity: _isOpen ? 0 : 1,
      child: FloatingActionButton.extended(
        key: _fabKey,
        // No hero: this FAB exists on multiple routes (Home + Daily Log); a
        // shared hero tag would make it "fly" across page transitions.
        heroTag: null,
        onPressed: _open,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
    );
  }
}

class _SpeedDialMenu extends StatelessWidget {
  const _SpeedDialMenu({
    required this.controller,
    required this.fabOffset,
    required this.fabSize,
    required this.onClose,
    required this.onAi,
    required this.onInventory,
  });

  final AnimationController controller;
  final Offset fabOffset;
  final Size fabSize;
  final VoidCallback onClose;
  final VoidCallback onAi;
  final VoidCallback onInventory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screen = MediaQuery.of(context).size;
    final rightInset = screen.width - (fabOffset.dx + fabSize.width);
    final bottomInset = screen.height - (fabOffset.dy + fabSize.height);

    final expand = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Container(
                color: scheme.scrim.withValues(alpha: 0.45 * controller.value),
              ),
            ),
          ),
        ),
        Positioned(
          right: rightInset,
          bottom: bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _action(
                context,
                expand: expand,
                label: 'Using AI',
                icon: Icons.auto_awesome_rounded,
                background: scheme.primary,
                foreground: scheme.onPrimary,
                onTap: onAi,
              ),
              const SizedBox(height: AppTheme.space12),
              _action(
                context,
                expand: expand,
                label: 'From inventory',
                icon: Icons.inventory_2_rounded,
                background: scheme.tertiary,
                foreground: scheme.onTertiary,
                onTap: onInventory,
              ),
              const SizedBox(height: AppTheme.space16),
              FloatingActionButton.extended(
                heroTag: null,
                onPressed: onClose,
                icon: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) => Transform.rotate(
                    angle: controller.value * 0.785398, // 45°
                    child: child,
                  ),
                  child: const Icon(Icons.add_rounded),
                ),
                label: const Text('Add entry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required Animation<double> expand,
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: expand,
      axisAlignment: 1,
      child: FadeTransition(
        opacity: controller,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: 8,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              FloatingActionButton.small(
                heroTag: 'speeddial_$label',
                onPressed: onTap,
                backgroundColor: background,
                foregroundColor: foreground,
                elevation: 2,
                child: Icon(icon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
