import 'package:flutter/material.dart';
import "../models/log_entry.dart";
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import '../utils/fasting_prompt.dart';

/// How the amount is being entered.
enum _LogMode { base, serving }

/// Standard household volume measures (US), with their millilitre equivalents.
enum _VolumeUnit { ml, tsp, tbsp, cup, flOz }

extension _VolumeUnitX on _VolumeUnit {
  double get ml {
    switch (this) {
      case _VolumeUnit.ml:
        return 1;
      case _VolumeUnit.tsp:
        return 5;
      case _VolumeUnit.tbsp:
        return 15;
      case _VolumeUnit.cup:
        return 240;
      case _VolumeUnit.flOz:
        return 30;
    }
  }

  String get label {
    switch (this) {
      case _VolumeUnit.ml:
        return 'ml';
      case _VolumeUnit.tsp:
        return 'tsp';
      case _VolumeUnit.tbsp:
        return 'tbsp';
      case _VolumeUnit.cup:
        return 'cup';
      case _VolumeUnit.flOz:
        return 'fl oz';
    }
  }
}

class LogEntryScreen extends StatefulWidget {
  final Map<String, dynamic> food;
  final String date;
  final bool editMode;
  final int? logId;

  /// Base amount (in g or ml) of the entry being edited. Passing this lets the
  /// screen render with the correct value on the first frame instead of loading
  /// asynchronously (which caused a visible flash / label overlap).
  final double? initialAmount;

  const LogEntryScreen({
    super.key,
    required this.food,
    required this.date,
    this.editMode = false,
    this.logId,
    this.initialAmount,
  });

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final TextEditingController _amountController = TextEditingController();
  final LogService _logService = LogService();

  late _LogMode _mode;
  _VolumeUnit _volumeUnit = _VolumeUnit.ml;

  /// The exact text seeded in edit mode, so we can persist the original,
  /// unrounded amount if the user doesn't actually change it.
  String? _seedText;

  bool get _isLiquid => (widget.food['unit']?.toString() ?? 'g') == 'ml';
  bool get _hasServing => widget.food['hasServing'] == true;
  String get _baseUnitLabel => _isLiquid ? 'ml' : 'g';

  double get _defaultPortionSize =>
      (widget.food['defaultPortionSize'] ?? 100.0).toDouble();
  String get _portionDescription =>
      widget.food['portionDescription']?.toString() ?? '100$_baseUnitLabel';

  double get _calPer100 => (widget.food['calories'] ?? 0).toDouble();
  double get _proteinPer100 => (widget.food['protein'] ?? 0).toDouble();
  double get _fatPer100 => (widget.food['fat'] ?? 0).toDouble();
  double get _carbsPer100 => (widget.food['carbs'] ?? 0).toDouble();

  double get _quantity => _parseQuantity(_amountController.text);

  /// Quantity converted to the food's base units (g or ml).
  double get _baseAmount {
    switch (_mode) {
      case _LogMode.serving:
        return _quantity * _defaultPortionSize;
      case _LogMode.base:
        if (_isLiquid) return _quantity * _volumeUnit.ml;
        return _quantity;
    }
  }

  Map<String, double> get _totals {
    final factor = _baseAmount / 100;
    return {
      'cal': _calPer100 * factor,
      'prot': _proteinPer100 * factor,
      'fat': _fatPer100 * factor,
      'carb': _carbsPer100 * factor,
    };
  }

  @override
  void initState() {
    super.initState();
    _mode = _LogMode.base;
    _volumeUnit = _VolumeUnit.ml;
    if (widget.editMode && widget.initialAmount != null) {
      // Render synchronously from the value we already have — no DB round-trip.
      _amountController.text = fmtNum(widget.initialAmount!);
      _seedText = _amountController.text;
    } else if (_hasServing && _defaultPortionSize > 0) {
      // Items with a defined serving default to the serving picker at 1 serving,
      // which is the most natural way to log inventory foods, recipes and AI meals.
      _mode = _LogMode.serving;
      _amountController.text = '1';
    } else {
      _amountController.text = _isLiquid ? '250' : '100';
    }
  }

  /// Converts a base amount (g/ml) into the quantity shown for a given mode/unit.
  double _qtyFor(double base, _LogMode mode, _VolumeUnit unit) {
    switch (mode) {
      case _LogMode.serving:
        return _defaultPortionSize > 0 ? base / _defaultPortionSize : 0;
      case _LogMode.base:
        if (_isLiquid) return unit.ml > 0 ? base / unit.ml : 0;
        return base;
    }
  }

  /// Switches measurement mode, converting the current value so it stays
  /// equivalent (e.g. 100 g -> 1 serving instead of 100 servings).
  void _changeMode(_LogMode mode) {
    final base = _baseAmount;
    setState(() {
      _mode = mode;
      _amountController.text = fmtNum(_qtyFor(base, mode, _volumeUnit));
    });
  }

  void _changeVolumeUnit(_VolumeUnit unit) {
    final base = _baseAmount;
    setState(() {
      _volumeUnit = unit;
      _amountController.text = fmtNum(_qtyFor(base, _mode, unit));
    });
  }

  /// Parses "1", "1.5", "1/2", "5/8" or mixed "1 1/2" into a double.
  double _parseQuantity(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    try {
      final parts = s.split(RegExp(r'\s+'));
      if (parts.length == 2 && parts[1].contains('/')) {
        return double.parse(parts[0]) + _parseFraction(parts[1]);
      }
      if (s.contains('/')) return _parseFraction(s);
      return double.parse(s);
    } catch (_) {
      return 0;
    }
  }

  double _parseFraction(String s) {
    final bits = s.split('/');
    if (bits.length != 2) return 0;
    final num = double.parse(bits[0]);
    final den = double.parse(bits[1]);
    if (den == 0) return 0;
    return num / den;
  }

  bool get _isValid => _amountController.text.trim().isNotEmpty && _quantity > 0;

  Future<void> _saveLog() async {
    if (!_isValid) return;

    // If the user never touched the seeded value, persist the original amount
    // verbatim so display-rounding never mutates stored data.
    final double baseAmount =
        (widget.editMode &&
                _seedText != null &&
                _amountController.text == _seedText &&
                _mode == _LogMode.base &&
                (!_isLiquid || _volumeUnit == _VolumeUnit.ml))
            ? widget.initialAmount!
            : _baseAmount;
    final portions = baseAmount / _defaultPortionSize;

    if (widget.editMode && widget.logId != null) {
      await _logService.updateLogEntry(
        LogEntry(
          id: widget.logId,
          foodId: widget.food['id'],
          amount: baseAmount,
          portions: portions,
          date: widget.date,
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      final entry = LogEntry(
        foodId: widget.food['id'],
        amount: baseAmount,
        portions: portions,
        date: widget.date,
      );
      await _logService.insertLogEntry(entry);

      if (mounted) {
        await FastingPrompt.showIfNeeded(
          context,
          loggedAt: entry.loggedAt,
          mealName: widget.food['name'] as String?,
        );
        if (!mounted) return;
      }
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    }
  }

  void _showDeleteConfirmation() async {
    if (!widget.editMode || widget.logId == null) return;

    final bool confirm =
        await AlertHelper.showConfirmationAlert(
          context,
          title: 'Delete Entry',
          message:
              'Are you sure you want to delete this ${widget.food['name']} entry?',
          confirmButtonText: 'Delete',
          type: AlertType.error,
        ) ??
        false;

    if (confirm) {
      await _logService.deleteLogEntry(widget.logId!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final t = _totals;
    final showModeToggle = _hasServing;
    final showFractionChips = _mode == _LogMode.serving || _isLiquid;

    return Scaffold(
      appBar: PageAppBar(title: widget.food['name']?.toString() ?? 'Entry'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.space8,
            AppTheme.pagePadding,
            AppTheme.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live totals hero.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total for this entry',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          fmtNum(t['cal']!),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'kcal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space12),

              // Distinct macro chips.
              Row(
                children: [
                  Expanded(
                    child: _macroChip('Protein', t['prot']!, scheme.primary),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: _macroChip('Carbs', t['carb']!, scheme.tertiary),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: _macroChip('Fat', t['fat']!, scheme.secondary),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                'Per 100 $_baseUnitLabel · ${fmtNum(_calPer100)} kcal · '
                'P ${fmtNum(_proteinPer100)} · '
                'C ${fmtNum(_carbsPer100)} · '
                'F ${fmtNum(_fatPer100)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space24),

              // Mode toggle (only when a serving is defined).
              if (showModeToggle) ...[
                Text('Measure by', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTheme.space8),
                SegmentedButton<_LogMode>(
                  segments: [
                    ButtonSegment(
                      value: _LogMode.base,
                      label: Text(_isLiquid ? 'Volume' : 'Weight'),
                      icon: Icon(
                        _isLiquid
                            ? Icons.local_drink_rounded
                            : Icons.scale_rounded,
                        size: 18,
                      ),
                    ),
                    const ButtonSegment(
                      value: _LogMode.serving,
                      label: Text('Servings'),
                      icon: Icon(Icons.lunch_dining_rounded, size: 18),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _changeMode(s.first),
                ),
                const SizedBox(height: AppTheme.space16),
              ],

              // For liquids in base mode: pick a household measure.
              if (_mode == _LogMode.base && _isLiquid) ...[
                Text('Volume unit', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: 8,
                  children: _VolumeUnit.values.map((u) {
                    return ChoiceChip(
                      label: Text(u.label),
                      selected: _volumeUnit == u,
                      onSelected: (_) => _changeVolumeUnit(u),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTheme.space16),
              ],

              // Amount input.
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9./ ]')),
                ],
                autofocus: !widget.editMode,
                onChanged: (_) => setState(() {}),
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: _amountLabel(),
                  suffixText: _amountSuffix(),
                  helperText: showFractionChips
                      ? 'Fractions allowed, e.g. 1 1/2'
                      : null,
                ),
              ),
              if (showFractionChips) ...[
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: 8,
                  children: const ['1/4', '1/3', '1/2', '2/3', '3/4', '1', '2']
                      .map(
                        (f) => ActionChip(
                          label: Text(f),
                          onPressed: () {
                            _amountController.text = f;
                            setState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_mode == _LogMode.serving || (_isLiquid && _volumeUnit != _VolumeUnit.ml))
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    '≈ ${fmtNum(_baseAmount)} $_baseUnitLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.space24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isValid ? _saveLog : null,
                  child: Text(widget.editMode ? 'Update entry' : 'Add to log'),
                ),
              ),
              if (widget.editMode) ...[
                const SizedBox(height: AppTheme.space12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showDeleteConfirmation,
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    label: Text(
                      'Delete entry',
                      style: TextStyle(color: scheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _amountLabel() {
    switch (_mode) {
      case _LogMode.serving:
        return 'Number of servings';
      case _LogMode.base:
        if (_isLiquid) return 'Amount (${_volumeUnit.label})';
        return 'Amount (g)';
    }
  }

  String _amountSuffix() {
    switch (_mode) {
      case _LogMode.serving:
        return _portionDescription;
      case _LogMode.base:
        return _isLiquid ? _volumeUnit.label : 'g';
    }
  }

  Widget _macroChip(String label, double value, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fmtNum(value)} g',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
