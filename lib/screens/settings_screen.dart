import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../services/settings_service.dart';
import '../services/scheduler_service.dart';
import '../services/debug_service.dart';
import '../widgets/custom_alert.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _calorieTargetController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  String? _selectedSex;
  String _selectedActivityLevel = 'moderate';
  String _selectedGoals = 'maintenance';
  final bool _isLoading = false;
  bool _isSaving = false;
  bool _isInitialized = false;
  
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
  }
  
  void _checkForChanges() {
    if (!_isInitialized) return; // Skip if not initialized
    
    final hasChanges = _apiKeyController.text != _originalApiKey ||
        _ageController.text != _originalAge ||
        _weightController.text != _originalWeight ||
        _heightController.text != _originalHeight ||
        _proteinController.text != _originalProtein ||
        _carbsController.text != _originalCarbs ||
        _fatController.text != _originalFat ||
        _selectedSex != _originalSex ||
        _selectedActivityLevel != _originalActivityLevel ||
        _selectedGoals != _originalGoals;
    
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<void> _loadSettings() async {
    final themeMode = await SettingsService.getThemeMode();
    final calorieTarget = await SettingsService.getCalorieTarget();
    final age = await SettingsService.getAge();
    final weight = await SettingsService.getWeight();
    final height = await SettingsService.getHeight();
    final sex = await SettingsService.getSex();
    final activityLevel = await SettingsService.getActivityLevel();
    final goals = await SettingsService.getGoals();
    final apiKey = await SettingsService.getGeminiApiKey();
    final macroTargets = await SettingsService.getMacroTargets();

    if (mounted) {
      setState(() {
        _selectedSex = sex;
        _selectedActivityLevel = activityLevel;
        _selectedGoals = goals;
        _apiKeyController.text = apiKey ?? '';
        _calorieTargetController.text = calorieTarget?.toString() ?? '';
        _ageController.text = age?.toString() ?? '';
        _weightController.text = weight?.toString() ?? '';
        _heightController.text = height?.toString() ?? '';
        _proteinController.text = macroTargets?['protein']?.toString() ?? '';
        _carbsController.text = macroTargets?['carbs']?.toString() ?? '';
        _fatController.text = macroTargets?['fat']?.toString() ?? '';
        
        // Store original values
        _originalSex = sex;
        _originalActivityLevel = activityLevel;
        _originalGoals = goals;
        _originalApiKey = apiKey ?? '';
        _originalAge = age?.toString() ?? '';
        _originalWeight = weight?.toString() ?? '';
        _originalHeight = height?.toString() ?? '';
        _originalProtein = macroTargets?['protein']?.toString() ?? '';
        _originalCarbs = macroTargets?['carbs']?.toString() ?? '';
        _originalFat = macroTargets?['fat']?.toString() ?? '';
      });
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);

    try {
      // Save API key
      await SettingsService.setGeminiApiKey(_apiKeyController.text.trim());
      
      // Save basic profile
      if (_ageController.text.isNotEmpty) {
        await SettingsService.setAge(int.tryParse(_ageController.text) ?? 0);
      }
      if (_weightController.text.isNotEmpty) {
        await SettingsService.setWeight(double.tryParse(_weightController.text) ?? 0);
      }
      if (_heightController.text.isNotEmpty) {
        await SettingsService.setHeight(double.tryParse(_heightController.text) ?? 0);
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

      // Setup notifications
      await SchedulerService.setupScheduledNotifications();

      // Update original values to current values
      _originalSex = _selectedSex;
      _originalActivityLevel = _selectedActivityLevel;
      _originalGoals = _selectedGoals;
      _originalApiKey = _apiKeyController.text.trim();
      _originalAge = _ageController.text;
      _originalWeight = _weightController.text;
      _originalHeight = _heightController.text;
      _originalProtein = _proteinController.text;
      _originalCarbs = _carbsController.text;
      _originalFat = _fatController.text;

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
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

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => CustomAlert(
        title: 'Unsaved Changes',
        message: 'You have unsaved changes. Do you want to leave without saving?',
        type: AlertType.warning,
        actionButtonText: 'Save & Leave',
        onActionPressed: () async {
          Navigator.of(context).pop(false);
          await _saveAllSettings();
          if (mounted) Navigator.of(context).pop();
        },
        onClose: () => Navigator.of(context).pop(true),
      ),
    ) ?? false;
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
    
    // Dispose controllers
    _apiKeyController.dispose();
    _calorieTargetController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return WillPopScope(
      onWillPop: _showUnsavedChangesDialog,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              final canPop = await _showUnsavedChangesDialog();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: _hasUnsavedChanges
              ? Row(
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: const Text(
                        'Unsaved',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  'Settings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          actions: [
            if (_hasUnsavedChanges) ...[
              IconButton(
                icon: _isSaving 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.save,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                onPressed: _isSaving ? null : _saveAllSettings,
                tooltip: 'Save All Settings',
              ),
            ],
            IconButton(
              icon: Icon(
                Icons.home_outlined, 
                color: Theme.of(context).colorScheme.primary, 
                size: 28,
              ),
              onPressed: () async {
                final canPop = await _showUnsavedChangesDialog();
                if (canPop && mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customize your nutrition tracking experience',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Theme Settings Section
                    _buildModernSection(
                      title: 'Theme',
                      icon: Icons.palette_outlined,
                      child: _buildThemeSelector(themeProvider),
                    ),
                    const SizedBox(height: 24),

                    // Profile Settings Section
                    _buildModernSection(
                      title: 'Profile',
                      icon: Icons.person_outline,
                      child: _buildModernProfileSection(),
                    ),
                    const SizedBox(height: 24),

                    // Nutrition Targets Section
                    _buildModernSection(
                      title: 'Nutrition Targets',
                      icon: Icons.track_changes_outlined,
                      child: _buildMacroTargetsSection(),
                    ),
                    const SizedBox(height: 24),

                    // AI Settings Section
                    _buildModernSection(
                      title: 'AI Configuration',
                      icon: Icons.smart_toy_outlined,
                      child: _buildModernApiKeySection(),
                    ),
                    
                    // Debug Testing Section (only in debug mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      _buildModernSection(
                        title: 'Debug Testing',
                        icon: Icons.bug_report_outlined,
                        child: _buildDebugTestingSection(),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
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
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
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
                      color: isSelected
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
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                        hintText: '25',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                        suffixText: 'years',
                  suffixStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
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
            ],
          ),
        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '70',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                        suffixText: 'kg',
                        suffixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                  hintText: '175',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  suffixText: 'cm',
                        suffixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
            Expanded(child: _buildModernOption('Male', _selectedSex == 'Male', () {
              setState(() => _selectedSex = 'Male');
              _checkForChanges();
            })),
            const SizedBox(width: 16),
            Expanded(child: _buildModernOption('Female', _selectedSex == 'Female', () {
              setState(() => _selectedSex = 'Female');
              _checkForChanges();
            })),
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
                Expanded(child: _buildModernOption('Sedentary', _selectedActivityLevel == 'sedentary', () {
                  setState(() => _selectedActivityLevel = 'sedentary');
                  _checkForChanges();
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildModernOption('Light', _selectedActivityLevel == 'light', () {
                  setState(() => _selectedActivityLevel = 'light');
                  _checkForChanges();
                })),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildModernOption('Moderate', _selectedActivityLevel == 'moderate', () {
                  setState(() => _selectedActivityLevel = 'moderate');
                  _checkForChanges();
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildModernOption('Very Active', _selectedActivityLevel == 'very_active', () {
                  setState(() => _selectedActivityLevel = 'very_active');
                  _checkForChanges();
                })),
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
                Expanded(child: _buildModernOption('Maintain', _selectedGoals == 'maintenance', () {
                  setState(() => _selectedGoals = 'maintenance');
                  _checkForChanges();
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildModernOption('Lose Weight', _selectedGoals == 'weight_loss', () {
                  setState(() => _selectedGoals = 'weight_loss');
                  _checkForChanges();
                })),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _buildModernOption('Gain Weight', _selectedGoals == 'weight_gain', () {
                setState(() => _selectedGoals = 'weight_gain');
                _checkForChanges();
              }),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
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
                Icon(
                  Icons.calculate,
                  color: Colors.orange,
                  size: 20,
                ),
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
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                    fontSize: 12,
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
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
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
              suffixStyle: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
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
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // API Key Input
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gemini AI API Key',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your Gemini AI API key',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: _isLoading
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
                onSubmitted: (_) => _saveAllSettings(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Information Card
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Nutrition Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoStep('1', 'Daily Analysis', 'AI analyzes your food intake at 10 PM'),
              const SizedBox(height: 12),
              _buildInfoStep('2', 'Smart Suggestions', 'Get 5 personalized nutrition tips'),
              const SizedBox(height: 12),
              _buildInfoStep('3', 'Motivation', 'Receive motivating quotes based on progress'),
              const SizedBox(height: 12),
              _buildInfoStep('4', 'Weekly Reports', 'Comprehensive weekly nutrition summaries'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.api,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Get your API key at ai.google.dev',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                        'Your API key is stored securely on your device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                        ),
                      ],
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

  Widget _buildInfoStep(String number, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
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
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
                    await SchedulerService.debugPerformDailyAnalysis(force: true);
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
                    _showSnackBar('System status logged to console', Colors.blue);
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
                    _showSnackBar('Full test completed! Check console.', Colors.green);
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
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
      ],
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