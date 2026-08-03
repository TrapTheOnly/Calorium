import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/log_entry.dart';
import '../models/food.dart';
import '../services/log_service.dart';
import '../utils/fasting_prompt.dart';
import '../utils/num_format.dart';
import '../services/food_service.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'settings_screen.dart';

/// AI-powered nutrition scanner.
///
/// When [date] is provided the result is logged to that day (with an optional
/// "save to inventory" toggle). When [date] is null the screen runs in
/// inventory-only mode: the analysed food is saved to the inventory and nothing
/// is logged.
class AiQuickAddScreen extends StatefulWidget {
  final String? date;

  const AiQuickAddScreen({super.key, this.date});

  @override
  State<AiQuickAddScreen> createState() => _AiQuickAddScreenState();
}

class _AiQuickAddScreenState extends State<AiQuickAddScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _nutritionData;
  bool _saveToInventory = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  bool _showPromptInput = false;

  bool get _inventoryOnly => widget.date == null;

  bool get _isLiquid {
    final desc =
        _nutritionData?['portionDescription']?.toString().toLowerCase() ?? '';
    final unit = _nutritionData?['unit']?.toString().toLowerCase() ?? '';
    return unit == 'ml' || desc.contains('ml');
  }

  String get _unitLabel => _isLiquid ? 'ml' : 'g';

  double get _calPer100 => (_nutritionData?['calories'] ?? 0).toDouble();
  double get _protPer100 => (_nutritionData?['protein'] ?? 0).toDouble();
  double get _carbPer100 => (_nutritionData?['carbs'] ?? 0).toDouble();
  double get _fatPer100 => (_nutritionData?['fat'] ?? 0).toDouble();

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _amountController.text = '100';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickWithApiKeyCheck(ImageSource source) async {
    final hasApiKey = await SettingsService.hasGeminiApiKey();
    if (!hasApiKey) {
      _showApiKeyDialog();
      return;
    }
    _pickImage(source);
  }

  void _showApiKeyDialog() {
    AlertHelper.showInfoAlert(
      context,
      title: 'API Key Required',
      message:
          'You need to set up your Gemini AI API key to use this feature. Would you like to go to settings now?',
      actionButtonText: 'Settings',
      onActionPressed: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _nutritionData = null;
          _showPromptInput = true;
          _amountController.text = '100';
        });
      }
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: source == ImageSource.camera ? 'Camera Error' : 'Gallery Error',
          message: 'Failed to get image: $e',
        );
      }
    }
  }

  Future<void> _analyzeWithPrompt() async {
    if (_selectedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _showPromptInput = false;
    });

    try {
      final nutritionData = await AiService.analyzeFood(
        _selectedImage!,
        userPrompt: _promptController.text.trim(),
      );
      if (!mounted) return;
      if (nutritionData != null) {
        setState(() {
          _nutritionData = nutritionData;
          _amountController.text =
              (nutritionData['defaultPortionSize'] ?? 100).toString();
        });
      } else {
        // The API returned nothing usable — don't strand the user on a blank
        // screen; surface an error and let them retry with more context.
        AlertHelper.showErrorAlert(
          context,
          title: 'Couldn\'t read that',
          message:
              'The AI didn\'t return nutrition data. Try again, add more context, or use a clearer photo.',
        );
        setState(() => _showPromptInput = true);
      }
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Analysis Failed',
          message:
              'Failed to analyze image. Please check your API key and try again.\n\nError: $e',
        );
        setState(() => _showPromptInput = true);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _nutritionData = null;
      _showPromptInput = false;
      _promptController.clear();
      _amountController.text = '100';
    });
  }

  Food _buildFood({required bool archived}) {
    final basis = _nutritionData?['basis']?.toString();
    final portion = (_nutritionData?['defaultPortionSize'] ?? 100).toDouble();
    // Treat a real portion (whole meal / per serving) as a serving so the item
    // defaults to the serving picker when logged later.
    final hasServing =
        basis != null && basis != 'per_100g' && portion > 0 && portion != 100;
    return Food(
      name: _nutritionData!['name']?.toString() ?? 'AI Analyzed Food',
      calories: _calPer100,
      protein: _protPer100,
      carbs: _carbPer100,
      fat: _fatPer100,
      defaultPortionSize: portion,
      portionDescription:
          _nutritionData!['portionDescription']?.toString() ??
              '1 serving (${fmtNum(portion)}$_unitLabel)',
      unit: _isLiquid ? 'ml' : 'g',
      hasServing: hasServing,
      type: 'simple',
      isArchived: archived,
    );
  }

  Future<void> _saveToInventoryOnly() async {
    if (_nutritionData == null) return;
    try {
      await FoodService().insertFood(_buildFood(archived: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_nutritionData!['name']} saved to your inventory.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Error Saving Food',
          message: 'Failed to save food to inventory: $e',
        );
      }
    }
  }

  Future<void> _addToLog() async {
    if (_nutritionData == null) return;
    if (_amount <= 0) {
      AlertHelper.showErrorAlert(
        context,
        title: 'Invalid Amount',
        message: 'Please enter a valid amount greater than 0.',
      );
      return;
    }

    try {
      final foodId = await FoodService().insertFood(
        _buildFood(archived: !_saveToInventory),
      );
      final logService = LogService();
      final entry =
          LogEntry(foodId: foodId, amount: _amount, date: widget.date!);
      await logService.insertLogEntry(entry);

      if (!mounted) return;
      await FastingPrompt.showIfNeeded(
        context,
        loggedAt: entry.loggedAt,
        mealName: _nutritionData!['name'] as String?,
      );
      if (!mounted) return;

      final inventoryMessage = _saveToInventory ? ' and saved to inventory' : '';
      AlertHelper.showSuccessAlert(
        context,
        title: 'Added to Log!',
        message:
            '${_nutritionData!['name']} has been added to your log$inventoryMessage.',
        actionButtonText: 'View Log',
        onActionPressed: () {
          Navigator.of(context).pop();
          Navigator.pop(context, true);
        },
      );
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Error Adding to Log',
          message: 'Failed to add food to log: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The bottom action bar must only appear on the final result view. While the
    // user is refining their note (or re-analyzing), the prompt UI owns its own
    // "Analyze" button, so showing "Add to log" here would let it be pressed by
    // mistake before the refined result is ready.
    final hasResult =
        _nutritionData != null && !_isAnalyzing && !_showPromptInput;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: PageAppBar(
        title: _inventoryOnly ? 'AI Scan to Inventory' : 'AI Quick Scan',
        subtitle: _inventoryOnly
            ? 'Photo a label or meal to save a food'
            : 'Photo a meal for instant nutrition',
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.space8,
                  AppTheme.pagePadding,
                  AppTheme.space16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedImage == null)
                      _buildPhotoPicker()
                    else ...[
                      _buildImageHeader(),
                      const SizedBox(height: AppTheme.space16),
                      if (_showPromptInput)
                        _buildPromptInput()
                      else if (_isAnalyzing)
                        _buildAnalyzing()
                      else if (_nutritionData != null) ...[
                        _buildResultCard(),
                        const SizedBox(height: AppTheme.space12),
                        _buildAmountCard(),
                        if (!_inventoryOnly) ...[
                          const SizedBox(height: AppTheme.space12),
                          _buildInventoryToggle(),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (hasResult) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  // --- Step 1: picker -------------------------------------------------------

  Widget _buildPhotoPicker() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.space32,
            horizontal: AppTheme.space16,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 30,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Scan a meal or a label',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                'Snap a plate, a package, or a screenshot of nutrition facts. '
                'The AI reads it and fills in the numbers.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pickWithApiKeyCheck(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take photo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _pickWithApiKeyCheck(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Image header (thumbnail + retake) ------------------------------------

  Widget _buildImageHeader() {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: _nutritionData != null ? 120 : 180,
            child: Image.file(_selectedImage!, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                onTap: _reset,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 16, color: scheme.onSurface),
                      const SizedBox(width: 4),
                      Text(
                        'Retake',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: prompt -------------------------------------------------------

  Widget _buildPromptInput() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add context (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Tell the AI the real weight or how to read the numbers — this makes '
            'the estimate far more accurate.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _promptController,
            keyboardType: TextInputType.text,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. "whole plate is ~350 g", "numbers are per 100 g", "no sugar"',
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _hintChip('Whole meal'),
              _hintChip('Per 100 g'),
              _hintChip('About 250 g'),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _analyzeWithPrompt,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Analyze'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintChip(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final existing = _promptController.text.trim();
        _promptController.text =
            existing.isEmpty ? text : '$existing, $text';
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
      },
    );
  }

  // --- Step 3: analyzing ----------------------------------------------------

  Widget _buildAnalyzing() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.all(AppTheme.space24),
      child: Column(
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: AppTheme.space16),
          Text(
            'Reading your image…',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Identifying the food and working out per-100g nutrition',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: results ------------------------------------------------------

  Widget _buildResultCard() {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final name = _nutritionData!['name']?.toString() ?? 'Unknown food';
    final basis = _nutritionData?['basis']?.toString();
    final note = _nutritionData?['note']?.toString();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.restaurant_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (basis != null) _basisChip(basis),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Per 100 $_unitLabel',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(
                child: _macroPill(
                    'Cal', fmtNum(_calPer100), 'kcal', scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroPill(
                    'Protein', fmtNum(_protPer100), 'g', scheme.tertiary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroPill(
                    'Carbs', fmtNum(_carbPer100), 'g', scheme.secondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroPill('Fat', fmtNum(_fatPer100), 'g', scheme.error),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showPromptInput = true),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Refine with a note'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _basisChip(String basis) {
    final scheme = Theme.of(context).colorScheme;
    // Describes how the AI interpreted the source numbers (not what the pills
    // below show — those are always normalised to per-100g).
    final label = switch (basis) {
      'per_100g' => 'Read: per 100 $_unitLabel',
      'per_serving' => 'Read: per serving',
      'whole_item' => 'Read: whole item',
      _ => basis,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _macroPill(String label, String value, String unit, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final factor = _amount / 100;
    final portionDesc =
        _nutritionData?['portionDescription']?.toString() ?? '';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _inventoryOnly ? 'Default serving size' : 'How much did you eat?',
            style: theme.textTheme.titleSmall,
          ),
          if (portionDesc.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              'AI estimate: $portionDesc',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_SingleDecimalFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _isLiquid ? 'Volume' : 'Weight',
              suffixText: _unitLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _inventoryOnly ? 'Per serving' : "You'll log",
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _totalChip(
                          fmtNum(_calPer100 * factor), 'kcal', scheme.primary),
                    ),
                    Expanded(
                      child: _totalChip(
                          fmtNum(_protPer100 * factor), 'P', scheme.tertiary),
                    ),
                    Expanded(
                      child: _totalChip(
                          fmtNum(_carbPer100 * factor), 'C', scheme.secondary),
                    ),
                    Expanded(
                      child: _totalChip(
                          fmtNum(_fatPer100 * factor), 'F', scheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalChip(String value, String unit, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryToggle() {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _saveToInventory,
        onChanged: (v) => setState(() => _saveToInventory = v),
        title: Text('Also save to inventory', style: theme.textTheme.titleSmall),
        subtitle: Text(
          'Keep this food for quick logging later',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space12,
        AppTheme.pagePadding,
        AppTheme.space16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _inventoryOnly ? _saveToInventoryOnly : _addToLog,
          icon: Icon(_inventoryOnly
              ? Icons.inventory_2_rounded
              : Icons.add_rounded),
          label: Text(
            _inventoryOnly
                ? 'Save to inventory'
                : (_saveToInventory ? 'Add to log & inventory' : 'Add to log'),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}

/// Allows digits and at most one decimal point.
class _SingleDecimalFormatter extends TextInputFormatter {
  static final RegExp _valid = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return _valid.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
