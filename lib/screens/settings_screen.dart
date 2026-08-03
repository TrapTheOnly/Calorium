import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../services/settings_service.dart';
import '../services/scheduler_service.dart';
import '../services/debug_service.dart';
import '../services/gemini_model_service.dart';
import '../services/fasting_service.dart';
import '../models/fasting_settings.dart';
import '../services/log_service.dart';
import '../services/health_service.dart';
import '../widgets/custom_alert.dart';
import '../widgets/fasting_overview_card.dart';
import '../widgets/ui_kit.dart';

/// The distinct settings areas, each shown on its own screen.
enum SettingsSection { appearance, profile, targets, fasting, reminders, ai, debug }

class SettingsScreen extends StatefulWidget {
  final bool asTabRoot;

  /// When null, the screen shows the settings index (a list of sections).
  /// When set, it shows that single section on its own screen.
  final SettingsSection? section;

  const SettingsScreen({super.key, this.asTabRoot = false, this.section});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _calorieTargetController =
      TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _geminiModelController = TextEditingController();
  List<String> _availableGeminiModels = [];
  bool _isFetchingModels = false;
  bool _hasFetchedGeminiModels = false;
  String? _selectedGeminiModel;
  String _originalGeminiModel = SettingsService.defaultGeminiModel;
  String? _modelFetchError;
  String? _selectedSex;
  String _selectedActivityLevel = 'moderate';
  String _selectedGoals = 'maintenance';
  final bool _isLoading = false;
  bool _isSaving = false;
  bool _isInitialized = false;

  static const double _minEatingHours = 4;
  static const double _maxEatingHours = 20;

  // Fasting settings
  bool _fastingEnabled = false;
  TimeOfDay _eatingStart = const TimeOfDay(hour: 12, minute: 0);
  double _eatingDurationHours = 8;

  // Reminder settings
  bool _dailyReminderEnabled = true;
  bool _weeklyReminderEnabled = true;
  bool? _notificationsPermissionGranted;

  bool _originalFastingEnabled = false;
  TimeOfDay _originalEatingStart = const TimeOfDay(hour: 12, minute: 0);
  double _originalEatingDurationHours = 8;

  // Debug preview controls
  double _debugStreakPreview = 0;
  double _debugHoursPreview = 4;
  bool _debugIsFastingPreview = false;

  // Change tracking
  bool _hasUnsavedChanges = false;

  // Original values for comparison
  String? _originalSex;
  String _originalActivityLevel = 'moderate';
  String _originalGoals = 'maintenance';
  String _originalApiKey = '';
  String _originalAge = '';
  String _originalWeight = '';
  String _originalHeight = '';
  String _originalProtein = '';
  String _originalCarbs = '';
  String _originalFat = '';

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) {
      _isInitialized = true;
      _setupChangeListeners();
      _checkForChanges(); // Check once after initialization
    });
  }

  void _setupChangeListeners() {
    _apiKeyController.addListener(_checkForChanges);
    _ageController.addListener(_checkForChanges);
    _weightController.addListener(_checkForChanges);
    _heightController.addListener(_checkForChanges);
    _proteinController.addListener(_checkForChanges);
    _carbsController.addListener(_checkForChanges);
    _fatController.addListener(_checkForChanges);
    _geminiModelController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    if (!_isInitialized) return; // Skip if not initialized

    final hasChanges =
        _apiKeyController.text != _originalApiKey ||
        _ageController.text != _originalAge ||
        _weightController.text != _originalWeight ||
        _heightController.text != _originalHeight ||
        _proteinController.text != _originalProtein ||
        _carbsController.text != _originalCarbs ||
        _fatController.text != _originalFat ||
        _selectedSex != _originalSex ||
        _selectedActivityLevel != _originalActivityLevel ||
        _selectedGoals != _originalGoals ||
        _geminiModelController.text != _originalGeminiModel ||
        _fastingEnabled != _originalFastingEnabled ||
        !_isSameTimeOfDay(_eatingStart, _originalEatingStart) ||
        (_eatingDurationHours - _originalEatingDurationHours).abs() > 0.01;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  bool _isSameTimeOfDay(TimeOfDay a, TimeOfDay b) {
    return a.hour == b.hour && a.minute == b.minute;
  }

  Future<void> _loadSettings() async {
    final calorieTarget = await SettingsService.getCalorieTarget();
    final age = await SettingsService.getAge();
    final weight = await SettingsService.getWeight();
    final height = await SettingsService.getHeight();
    final sex = await SettingsService.getSex();
    final activityLevel = await SettingsService.getActivityLevel();
    final goals = await SettingsService.getGoals();
    final apiKey = await SettingsService.getGeminiApiKey();
    final geminiModel = await SettingsService.getGeminiModel();
    final macroTargets = await SettingsService.getMacroTargets();
    final fastingSettings = await FastingService.getSettings();
    final dailyReminder = await SettingsService.isDailyReminderEnabled();
    final weeklyReminder = await SettingsService.isWeeklyReminderEnabled();
    final notifEnabled = await SchedulerService.areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _dailyReminderEnabled = dailyReminder;
        _weeklyReminderEnabled = weeklyReminder;
        _notificationsPermissionGranted = notifEnabled;
        _selectedSex = sex;
        _selectedActivityLevel = activityLevel;
        _selectedGoals = goals;
        _apiKeyController.text = apiKey ?? '';
        _selectedGeminiModel = geminiModel;
        _geminiModelController.text = geminiModel;
        _availableGeminiModels = [geminiModel];
        _calorieTargetController.text = calorieTarget?.toString() ?? '';
        _ageController.text = age?.toString() ?? '';
        _weightController.text = weight?.toString() ?? '';
        _heightController.text = height?.toString() ?? '';
        _proteinController.text = macroTargets?['protein']?.toString() ?? '';
        _carbsController.text = macroTargets?['carbs']?.toString() ?? '';
        _fatController.text = macroTargets?['fat']?.toString() ?? '';

        _fastingEnabled = fastingSettings.enabled;
        _eatingStart = fastingSettings.eatingStartTime;
        final eatingHours = fastingSettings.eatingDurationMinutes / 60.0;
        _eatingDurationHours = eatingHours.clamp(
          _minEatingHours,
          _maxEatingHours,
        );

        // Store original values
        _originalSex = sex;
        _originalActivityLevel = activityLevel;
        _originalGoals = goals;
        _originalApiKey = apiKey ?? '';
        _originalGeminiModel = geminiModel;
        _originalAge = age?.toString() ?? '';
        _originalWeight = weight?.toString() ?? '';
        _originalHeight = height?.toString() ?? '';
        _originalProtein = macroTargets?['protein']?.toString() ?? '';
        _originalCarbs = macroTargets?['carbs']?.toString() ?? '';
        _originalFat = macroTargets?['fat']?.toString() ?? '';
        _originalFastingEnabled = fastingSettings.enabled;
        _originalEatingStart = fastingSettings.eatingStartTime;
        _originalEatingDurationHours = eatingHours.clamp(
          _minEatingHours,
          _maxEatingHours,
        );
      });
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);

    try {
      // Save API key
      await SettingsService.setGeminiApiKey(_apiKeyController.text.trim());

      // Save Gemini model selection
      final trimmedModel = _geminiModelController.text.trim();
      final modelToSave = SettingsService.normalizeGeminiModelName(
        trimmedModel.isEmpty
            ? SettingsService.defaultGeminiModel
            : trimmedModel,
      );
      await SettingsService.setGeminiModel(modelToSave);
      if (trimmedModel != modelToSave) {
        _geminiModelController.text = modelToSave;
      }

      // Save basic profile
      if (_ageController.text.isNotEmpty) {
        await SettingsService.setAge(int.tryParse(_ageController.text) ?? 0);
      }
      if (_weightController.text.isNotEmpty) {
        await SettingsService.setWeight(
          double.tryParse(_weightController.text) ?? 0,
        );
      }
      if (_heightController.text.isNotEmpty) {
        await SettingsService.setHeight(
          double.tryParse(_heightController.text) ?? 0,
        );
      }
      if (_selectedSex != null) {
        await SettingsService.setSex(_selectedSex!);
      }
      await SettingsService.setActivityLevel(_selectedActivityLevel);
      await SettingsService.setGoals(_selectedGoals);

      // Save macro targets if all are provided
      if (_proteinController.text.isNotEmpty &&
          _carbsController.text.isNotEmpty &&
          _fatController.text.isNotEmpty) {
        final protein = double.tryParse(_proteinController.text) ?? 0;
        final carbs = double.tryParse(_carbsController.text) ?? 0;
        final fat = double.tryParse(_fatController.text) ?? 0;

        await SettingsService.setMacroTargets(protein, carbs, fat);
      }

      // Setup notifications with error handling
      try {
        await SchedulerService.setupScheduledNotifications();
      } catch (e) {
        print('Warning: Failed to setup notifications: $e');
        // Continue with saving - notifications are not critical
      }

      // Update original values to current values
      _originalSex = _selectedSex;
      _originalActivityLevel = _selectedActivityLevel;
      _originalGoals = _selectedGoals;
      _originalApiKey = _apiKeyController.text.trim();
      _originalGeminiModel = modelToSave;
      _originalAge = _ageController.text;
      _originalWeight = _weightController.text;
      _originalHeight = _heightController.text;
      _originalProtein = _proteinController.text;
      _originalCarbs = _carbsController.text;
      _originalFat = _fatController.text;
      await FastingService.saveSettings(
        FastingSettings(
          enabled: _fastingEnabled,
          eatingStartMinutes: _eatingStart.hour * 60 + _eatingStart.minute,
          eatingDurationMinutes: (_eatingDurationHours * 60).round(),
        ),
      );

      if (_fastingEnabled && !_originalFastingEnabled) {
        await FastingService.initializeStreak(DateTime.now());
      } else if (!_fastingEnabled && _originalFastingEnabled) {
        await FastingService.clearStreak();
      }

      _originalFastingEnabled = _fastingEnabled;
      _originalEatingStart = _eatingStart;
      _originalEatingDurationHours = _eatingDurationHours;

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
        _selectedGeminiModel = modelToSave;
      });

      if (mounted) {
        AlertHelper.showSuccessAlert(
          context,
          title: 'Settings Saved',
          message: 'All your settings have been saved successfully!',
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Save Failed',
          message: 'Error saving settings: $e',
        );
      }
    }
  }

  void _applyGeminiModelSelection(String model) {
    _geminiModelController.text = model;
    setState(() {
      _selectedGeminiModel = model;
      final updatedModels = {..._availableGeminiModels, model};
      _availableGeminiModels = updatedModels.toList()..sort();
    });
    _checkForChanges();
  }

  void _updateGeminiModelOptions(List<String> models, {String? infoMessage}) {
    final currentValue = _geminiModelController.text.trim();
    final normalizedCurrent =
        currentValue.isEmpty
            ? ''
            : SettingsService.normalizeGeminiModelName(currentValue);

    final normalizedModels =
        models
            .map(SettingsService.normalizeGeminiModelName)
            .where((model) => model.isNotEmpty)
            .toSet();

    if (normalizedCurrent.isNotEmpty) {
      normalizedModels.add(normalizedCurrent);
    }

    final sortedModels = normalizedModels.toList()..sort();

    setState(() {
      _availableGeminiModels = sortedModels;
      _hasFetchedGeminiModels = true;
      _modelFetchError = infoMessage;

      if (normalizedCurrent.isNotEmpty &&
          sortedModels.contains(normalizedCurrent)) {
        _selectedGeminiModel = normalizedCurrent;
        if (_geminiModelController.text != normalizedCurrent) {
          _geminiModelController.text = normalizedCurrent;
        }
      } else if (sortedModels.isNotEmpty) {
        final nextSelection = sortedModels.first;
        _selectedGeminiModel = nextSelection;
        if (_geminiModelController.text != nextSelection) {
          _geminiModelController.text = nextSelection;
        }
      } else {
        _selectedGeminiModel =
            normalizedCurrent.isNotEmpty ? normalizedCurrent : null;
      }
    });
  }

  Future<void> _fetchAvailableGeminiModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'API Key Required',
          message:
              'Please add your Gemini API key before fetching available models.',
        );
      }
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _modelFetchError = null;
    });

    try {
      final models = await GeminiModelService.fetchAvailableModels(apiKey);

      if (!mounted) return;

      _updateGeminiModelOptions(models);
      _checkForChanges();
    } on GeminiModelFetchException catch (e) {
      if (!mounted) return;

      if (e.fallbackModels.isNotEmpty) {
        _updateGeminiModelOptions(e.fallbackModels, infoMessage: e.message);
        _checkForChanges();

        AlertHelper.showInfoAlert(
          context,
          title: 'Connection Warning',
          message:
              '${e.message}\n\nLoaded a fallback list of common Gemini models so you can continue working. Please fix the device date/time and try again for the latest list.',
        );
      } else {
        setState(() {
          _modelFetchError = e.message;
        });
        AlertHelper.showErrorAlert(
          context,
          title: 'Fetch Failed',
          message: e.message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString();
      setState(() {
        _modelFetchError = errorMessage;
      });
      AlertHelper.showErrorAlert(
        context,
        title: 'Fetch Failed',
        message: 'Unable to fetch Gemini models. $errorMessage',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingModels = false;
        });
      }
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => CustomAlert(
                title: 'Unsaved Changes',
                message:
                    'You have unsaved changes. Do you want to leave without saving?',
                type: AlertType.warning,
                actionButtonText: 'Save & Leave',
                onActionPressed: () async {
                  Navigator.of(context).pop(false);
                  await _saveAllSettings();
                  if (mounted) Navigator.of(context).pop();
                },
                onClose: () => Navigator.of(context).pop(true),
              ),
        ) ??
        false;
  }

  @override
  void dispose() {
    // Remove change listeners
    _apiKeyController.removeListener(_checkForChanges);
    _ageController.removeListener(_checkForChanges);
    _weightController.removeListener(_checkForChanges);
    _heightController.removeListener(_checkForChanges);
    _proteinController.removeListener(_checkForChanges);
    _carbsController.removeListener(_checkForChanges);
    _fatController.removeListener(_checkForChanges);
    _geminiModelController.removeListener(_checkForChanges);

    // Dispose controllers
    _apiKeyController.dispose();
    _calorieTargetController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _geminiModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section == null) {
      return _buildIndex();
    }
    return _buildSectionScreen(widget.section!);
  }

  ({String title, IconData icon, String subtitle}) _sectionInfo(
    SettingsSection section,
  ) {
    switch (section) {
      case SettingsSection.appearance:
        return (
          title: 'Appearance',
          icon: Icons.palette_outlined,
          subtitle: 'Theme and colors',
        );
      case SettingsSection.profile:
        return (
          title: 'Profile & Goals',
          icon: Icons.person_outline,
          subtitle: 'Body metrics and calorie target',
        );
      case SettingsSection.targets:
        return (
          title: 'Nutrition Targets',
          icon: Icons.track_changes_outlined,
          subtitle: 'Protein, carbs, and fat goals',
        );
      case SettingsSection.fasting:
        return (
          title: 'Intermittent Fasting',
          icon: Icons.timelapse_outlined,
          subtitle: 'Eating window and schedule',
        );
      case SettingsSection.reminders:
        return (
          title: 'Reminders',
          icon: Icons.notifications_outlined,
          subtitle: 'Daily and weekly notifications',
        );
      case SettingsSection.ai:
        return (
          title: 'AI Configuration',
          icon: Icons.smart_toy_outlined,
          subtitle: 'Gemini API key and model',
        );
      case SettingsSection.debug:
        return (
          title: 'Debug Testing',
          icon: Icons.bug_report_outlined,
          subtitle: 'Developer tools',
        );
    }
  }

  Widget _sectionContent(SettingsSection section) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    switch (section) {
      case SettingsSection.appearance:
        return _buildThemeSelector(themeProvider);
      case SettingsSection.profile:
        return _buildModernProfileSection();
      case SettingsSection.targets:
        return _buildMacroTargetsSection();
      case SettingsSection.fasting:
        return _buildFastingSection();
      case SettingsSection.reminders:
        return _buildRemindersSection();
      case SettingsSection.ai:
        return _buildModernApiKeySection();
      case SettingsSection.debug:
        return _buildDebugTestingSection();
    }
  }

  Widget _buildIndex() {
    final sections = <SettingsSection>[
      SettingsSection.appearance,
      SettingsSection.profile,
      SettingsSection.targets,
      SettingsSection.fasting,
      SettingsSection.reminders,
      SettingsSection.ai,
      if (kDebugMode) SettingsSection.debug,
    ];

    return Scaffold(
      appBar: PageAppBar(
        title: 'Settings',
        subtitle: 'Customize tracking, reminders, and AI',
        automaticallyImplyLeading: !widget.asTabRoot,
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final info = _sectionInfo(sections[index]);
            return NavRow(
              icon: info.icon,
              title: info.title,
              subtitle: info.subtitle,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(section: sections[index]),
                  ),
                );
                if (mounted) _loadSettings();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionScreen(SettingsSection section) {
    final info = _sectionInfo(section);
    final scheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: _showUnsavedChangesDialog,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canPop = await _showUnsavedChangesDialog();
              if (canPop && mounted) Navigator.of(context).pop();
            },
          ),
          title: Row(
            children: [
              Flexible(child: Text(info.title)),
              if (_hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Unsaved',
                    style: TextStyle(
                      color: scheme.onTertiaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveAllSettings,
                tooltip: 'Save',
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _sectionContent(section),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider) {
    return Column(
      children: [
        _buildModernThemeOption(
          'System',
          'Follow system settings',
          Icons.brightness_auto,
          ThemeOption.system,
          themeProvider,
        ),
        const SizedBox(height: 12),
        _buildModernThemeOption(
          'Light',
          'Always use light mode',
          Icons.light_mode,
          ThemeOption.light,
          themeProvider,
        ),
        const SizedBox(height: 12),
        _buildModernThemeOption(
          'Dark',
          'Always use dark mode',
          Icons.dark_mode,
          ThemeOption.dark,
          themeProvider,
        ),
      ],
    );
  }

  Widget _buildModernThemeOption(
    String title,
    String description,
    IconData icon,
    ThemeOption option,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeOption == option;

    return GestureDetector(
      onTap: () => themeProvider.setThemeOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Info
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        // Age and Weight Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Age',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '25',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        suffixText: 'years',
                        suffixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '70',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        suffixText: 'kg',
                        suffixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Height - Full Width
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Height',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '175',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  suffixText: 'cm',
                  suffixStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Gender',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernOption('Male', _selectedSex == 'Male', () {
                setState(() => _selectedSex = 'Male');
                _checkForChanges();
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernOption('Female', _selectedSex == 'Female', () {
                setState(() => _selectedSex = 'Female');
                _checkForChanges();
              }),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Activity Level
        Text(
          'Activity Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildModernOption(
                    'Sedentary',
                    _selectedActivityLevel == 'sedentary',
                    () {
                      setState(() => _selectedActivityLevel = 'sedentary');
                      _checkForChanges();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModernOption(
                    'Light',
                    _selectedActivityLevel == 'light',
                    () {
                      setState(() => _selectedActivityLevel = 'light');
                      _checkForChanges();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildModernOption(
                    'Moderate',
                    _selectedActivityLevel == 'moderate',
                    () {
                      setState(() => _selectedActivityLevel = 'moderate');
                      _checkForChanges();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModernOption(
                    'Very Active',
                    _selectedActivityLevel == 'very_active',
                    () {
                      setState(() => _selectedActivityLevel = 'very_active');
                      _checkForChanges();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Goals
        Text(
          'Goals',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildModernOption(
                    'Maintain',
                    _selectedGoals == 'maintenance',
                    () {
                      setState(() => _selectedGoals = 'maintenance');
                      _checkForChanges();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModernOption(
                    'Lose Weight',
                    _selectedGoals == 'weight_loss',
                    () {
                      setState(() => _selectedGoals = 'weight_loss');
                      _checkForChanges();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _buildModernOption(
                'Gain Weight',
                _selectedGoals == 'weight_gain',
                () {
                  setState(() => _selectedGoals = 'weight_gain');
                  _checkForChanges();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        Text(
          'Health Connect',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share logged meals with Google Health and other apps. '
          'Use resync to backfill meals logged before write access was enabled.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _resyncMealsToHealth,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Resync meals to Health Connect'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _resyncMealsToHealth() async {
    try {
      _showSnackBar('Requesting permission & syncing…', Colors.blue);
      // Capture write access *before* prompting so resync can reconcile
      // legacy (pre-v9) rows that were already mirrored at insert time.
      final alreadyHadWrite =
          await HealthService.instance.hasNutritionWritePermission();
      final granted = alreadyHadWrite ||
          await HealthService.instance.requestNutritionWritePermission();
      if (!granted) {
        if (!mounted) return;
        AlertHelper.showInfoAlert(
          context,
          title: 'Permission needed',
          message:
              'Allow Calorium to write nutrition in Health Connect, then try again.',
        );
        return;
      }
      final count = await LogService().resyncMealsToHealthConnect(
        alreadyHadWrite: alreadyHadWrite,
      );
      if (!mounted) return;
      if (count == 0) {
        _showSnackBar('No meals to sync in the last 90 days.', Colors.orange);
      } else {
        _showSnackBar(
          'Synced $count meal${count == 1 ? '' : 's'} to Health Connect.',
          Colors.green,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Resync failed: $e', Colors.red);
    }
  }

  Widget _buildRemindersSection() {
    final theme = Theme.of(context);
    final supported = SchedulerService.isSupported;

    if (!supported) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reminders are only available on Android and iOS. '
                'Run the app on a mobile device to configure notifications.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final permissionLabel =
        _notificationsPermissionGranted == null
            ? 'Checking…'
            : (_notificationsPermissionGranted!
                ? 'Notifications allowed'
                : 'Notifications blocked — enable in system settings');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          permissionLabel,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reminders open the app so analysis can run. Background AI is not run while the app is closed.',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Daily check-in (10 PM)'),
          subtitle: const Text('Evening reminder to review today\'s log'),
          value: _dailyReminderEnabled,
          onChanged: (value) async {
            if (value) {
              final granted =
                  await SchedulerService.requestNotificationPermissions();
              setState(() => _notificationsPermissionGranted = granted);
            }
            setState(() => _dailyReminderEnabled = value);
            await SettingsService.setDailyReminderEnabled(value);
            await SchedulerService.setupScheduledNotifications();
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Weekly review (Sun 8 PM)'),
          subtitle: const Text('Sunday reminder to open Insights'),
          value: _weeklyReminderEnabled,
          onChanged: (value) async {
            if (value) {
              final granted =
                  await SchedulerService.requestNotificationPermissions();
              setState(() => _notificationsPermissionGranted = granted);
            }
            setState(() => _weeklyReminderEnabled = value);
            await SettingsService.setWeeklyReminderEnabled(value);
            await SchedulerService.setupScheduledNotifications();
          },
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await SchedulerService.showTestNotification();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification sent')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not send test: $e')),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send test'),
            ),
            if (kDebugMode)
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await SchedulerService.scheduleShortDelayTest();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scheduled test in ~15 seconds'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not schedule test: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Schedule 15s test'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFastingSection() {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final startLabel = localizations.formatTimeOfDay(_eatingStart);
    final fastingLabel = _formatHours(24 - _eatingDurationHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eating schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose when your eating window begins and how long it stays open.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _fastingEnabled,
              onChanged: (value) {
                setState(() {
                  _fastingEnabled = value;
                });
                _checkForChanges();
              },
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              !_fastingEnabled
                  ? Container(
                    key: const ValueKey('fasting-disabled'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.slow_motion_video,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Keep fasting off and the home screen will stay focused on calorie tracking only.',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    key: const ValueKey('fasting-enabled'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEatingStartPicker(theme, startLabel),
                      const SizedBox(height: 20),
                      _buildEatingDurationSlider(theme, fastingLabel),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildEatingStartPicker(ThemeData theme, String timeLabel) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _eatingStart,
          helpText: 'Select eating start time',
        );
        if (picked != null) {
          setState(() {
            _eatingStart = picked;
          });
          _checkForChanges();
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lunch_dining,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eating window begins',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildEatingDurationSlider(ThemeData theme, String fastingLabel) {
    final eatingLabel = _formatHours(_eatingDurationHours);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Eating duration',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$eatingLabel hrs eat · $fastingLabel hrs fast',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: _eatingDurationHours,
            min: _minEatingHours,
            max: _maxEatingHours,
            divisions: ((_maxEatingHours - _minEatingHours) * 2).round(),
            label: '$eatingLabel hrs',
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.primary.withOpacity(0.2),
            onChanged: (value) {
              final stepped = (value * 2).round() / 2;
              setState(() {
                _eatingDurationHours = stepped.clamp(
                  _minEatingHours,
                  _maxEatingHours,
                );
              });
              _checkForChanges();
            },
          ),
        ),
        Text(
          'Tip: Keep the eating duration consistent so your fasting window stays predictable.',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatHours(double hours) {
    return (hours % 1).abs() < 0.01
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
  }

  Widget _buildMacroTargetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your daily macro targets manually',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Calculated Calories Display
        if (_calculatedCalories > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calculate, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Calculated: ${_calculatedCalories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Macro Input Fields
        _buildMacroInputField(
          'Protein',
          _proteinController,
          'g',
          Colors.red,
          Icons.fitness_center,
        ),
        const SizedBox(height: 16),
        _buildMacroInputField(
          'Carbohydrates',
          _carbsController,
          'g',
          Colors.amber,
          Icons.grain,
        ),
        const SizedBox(height: 16),
        _buildMacroInputField(
          'Fat',
          _fatController,
          'g',
          Colors.purple,
          Icons.opacity,
        ),

        const SizedBox(height: 20),

        // Quick calculation info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formula: (Protein × 4) + (Carbs × 4) + (Fat × 9)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroInputField(
    String label,
    TextEditingController controller,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}), // Refresh calculated calories
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernApiKeySection() {
    final trimmedModelValue = _geminiModelController.text.trim();
    final dropdownModels =
        <String>{
            ..._availableGeminiModels,
            if (trimmedModelValue.isNotEmpty) trimmedModelValue,
          }.toList()
          ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // API Key Input
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.vpn_key,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gemini AI API Key',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Paste your Gemini API key here',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon:
                      _isLoading
                          ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: _saveAllSettings,
                          ),
                ),
                onChanged: (_) {
                  if (_hasFetchedGeminiModels) {
                    setState(() {
                      _hasFetchedGeminiModels = false;
                      _modelFetchError = null;
                      _availableGeminiModels = [
                        if (_geminiModelController.text.trim().isNotEmpty)
                          _geminiModelController.text.trim(),
                      ];
                    });
                  }
                },
                onSubmitted: (_) => _saveAllSettings(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Gemini Model Selection
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gemini Model Version',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Select the Gemini model you want to use for AI-powered features. You can fetch the latest list from Google AI or enter a version manually.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.65),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _geminiModelController,
                onChanged: (value) {
                  final trimmed = value.trim();
                  final newValue = trimmed.isEmpty ? null : trimmed;
                  if (_selectedGeminiModel == newValue) return;
                  setState(() {
                    _selectedGeminiModel = newValue;
                  });
                },
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Model identifier',
                  hintText: 'gemini-1.5-flash-latest',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed:
                            _isFetchingModels
                                ? null
                                : _fetchAvailableGeminiModels,
                        icon:
                            _isFetchingModels
                                ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.refresh),
                        label: const Text('Get models'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _applyGeminiModelSelection(
                            SettingsService.defaultGeminiModel,
                          );
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Use default'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isFetchingModels) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Fetching available models...',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
              if (_hasFetchedGeminiModels &&
                  _availableGeminiModels.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value:
                      dropdownModels.contains(_selectedGeminiModel)
                          ? _selectedGeminiModel
                          : (dropdownModels.contains(trimmedModelValue)
                              ? trimmedModelValue
                              : null),
                  decoration: InputDecoration(
                    labelText: 'Available models',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  menuMaxHeight: 320,
                  borderRadius: BorderRadius.circular(18),
                  dropdownColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.95),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  items:
                      dropdownModels
                          .map(
                            (model) => DropdownMenuItem<String>(
                              value: model,
                              child: Text(model),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _applyGeminiModelSelection(value);
                  },
                ),
              ],
              if (_modelFetchError != null && _modelFetchError!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _modelFetchError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // How to Get API Key Section
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.1),
                Colors.blue.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Get Your Free API Key',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildApiStep(
                '1',
                'Visit Google AI Studio',
                'Go to aistudio.google.com and sign in with your Google account',
              ),
              const SizedBox(height: 12),
              _buildApiStep(
                '2',
                'Create API Key',
                'Click "Get API Key" → "Create API Key" → "Create API key in new project"',
              ),
              const SizedBox(height: 12),
              _buildApiStep(
                '3',
                'Copy & Secure',
                'Copy the 40-character key and paste it above. Keep it private!',
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '100% Free • No billing required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Features Section
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.withOpacity(0.1),
                Colors.purple.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI-Powered Features',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                Icons.analytics_outlined,
                'Smart Daily Analysis',
                'AI analyzes your daily food intake and provides personalized nutrition insights based on your goals and dietary patterns.',
                Colors.orange,
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                Icons.lightbulb_outline,
                'Personalized Suggestions',
                'Get 5 tailored recommendations daily to improve your nutrition, optimize macros, and reach your health goals.',
                Colors.blue,
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                Icons.favorite_outline,
                'Motivational Coaching',
                'Receive encouraging quotes and motivation based on your progress, helping you stay committed to your health journey.',
                Colors.pink,
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                Icons.trending_up,
                'Weekly Progress Reports',
                'Comprehensive weekly summaries with insights, trends, and actionable recommendations for long-term success.',
                Colors.green,
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                Icons.schedule,
                'Automated Scheduling',
                'Daily analysis at 10 PM and weekly reports on Sundays - all automated with smart notifications.',
                Colors.indigo,
              ),

              const SizedBox(height: 16),

              // Privacy & Security Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Privacy & Security',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Your API key is stored securely on your device only\n'
                      '• Nutrition data is analyzed in real-time, not stored by Google\n'
                      '• You maintain full control over your data and privacy\n'
                      '• All AI processing happens through encrypted connections',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugTestingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.amber[700], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Debug Mode Only - Test AI nutrition analysis features',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notification Testing
        Text(
          'Test Notifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await SchedulerService.showTestNotification();
                    _showSnackBar('Test notification sent!', Colors.green);
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.notifications, size: 18),
                label: Text('Basic Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await SchedulerService.debugTriggerDailyNotification();
                    _showSnackBar('Daily notification sent!', Colors.green);
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.today, size: 18),
                label: Text('Daily'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await SchedulerService.debugTriggerWeeklyNotification();
                    _showSnackBar('Weekly notification sent!', Colors.green);
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.calendar_view_week, size: 18),
                label: Text('Weekly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // AI Analysis Testing
        Text(
          'Test AI Analysis',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    _showSnackBar('Running daily analysis...', Colors.blue);
                    await SchedulerService.debugPerformDailyAnalysis(
                      force: true,
                    );
                    _showSnackBar('Daily analysis completed!', Colors.green);
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.analytics, size: 18),
                label: Text('Daily Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    _showSnackBar('Running weekly analysis...', Colors.blue);
                    await SchedulerService.debugPerformWeeklyAnalysis();
                    _showSnackBar('Weekly analysis completed!', Colors.green);
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.insert_chart, size: 18),
                label: Text('Weekly Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // System Status & Full Test
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await DebugService.status();
                    _showSnackBar(
                      'System status logged to console',
                      Colors.blue,
                    );
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.health_and_safety, size: 18),
                label: Text('Check Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    _showSnackBar('Running full test suite...', Colors.blue);
                    await SchedulerService.debugFullTestSuite();
                    _showSnackBar(
                      'Full test completed! Check console.',
                      Colors.green,
                    );
                  } catch (e) {
                    _showSnackBar('Error: $e', Colors.red);
                  }
                },
                icon: Icon(Icons.play_circle_filled, size: 18),
                label: Text('Full Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Debug Tips',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Test basic notification first to verify permissions\n'
                '• Check system status before running AI analysis\n'
                '• Watch console output for detailed results\n'
                '• Ensure API key and profile are configured',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Fasting Card Preview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Eating'),
              selected: !_debugIsFastingPreview,
              onSelected: (selected) {
                if (!selected) return;
                setState(() => _debugIsFastingPreview = false);
              },
            ),
            ChoiceChip(
              label: const Text('Fasting'),
              selected: _debugIsFastingPreview,
              onSelected: (selected) {
                if (!selected) return;
                setState(() => _debugIsFastingPreview = true);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Hours remaining: ${_debugHoursPreview.toStringAsFixed(1)}h',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: _debugHoursPreview,
          min: 0.25,
          max: 24,
          divisions: 95,
          label: '${_debugHoursPreview.toStringAsFixed(1)}h',
          onChanged: (value) {
            setState(() => _debugHoursPreview = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Streak days preview: ${_debugStreakPreview.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: _debugStreakPreview,
          min: 0,
          max: 15,
          divisions: 15,
          label: _debugStreakPreview.toStringAsFixed(0),
          onChanged: (value) {
            setState(() => _debugStreakPreview = value);
          },
        ),
        const SizedBox(height: 16),
        _buildFastingPreviewCard(),
      ],
    );
  }

  Widget _buildFastingPreviewCard() {
    final now = DateTime.now();
    final settingsSample = const FastingSettings(
      enabled: true,
      eatingStartMinutes: 12 * 60,
      eatingDurationMinutes: 8 * 60,
    );

    final totalDuration =
        _debugIsFastingPreview
            ? settingsSample.fastingDuration
            : settingsSample.eatingDuration;
    final remainingMinutes = (_debugHoursPreview * 60).clamp(
      1,
      totalDuration.inMinutes.toDouble(),
    );
    final remaining = Duration(minutes: remainingMinutes.round());
    final elapsed = totalDuration - remaining;

    final status = FastingStatus(
      enabled: true,
      phase:
          _debugIsFastingPreview ? FastingPhase.fasting : FastingPhase.eating,
      phaseStart: now.subtract(elapsed),
      phaseEnd: now.add(remaining),
      reference: now,
    );

    return FastingOverviewCard(
      status: status,
      settings: settingsSample,
      streakDays: _debugStreakPreview.round(),
      timeRemaining: remaining,
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  double get _calculatedCalories {
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carbs = double.tryParse(_carbsController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    return (protein * 4) + (carbs * 4) + (fat * 9);
  }
}
