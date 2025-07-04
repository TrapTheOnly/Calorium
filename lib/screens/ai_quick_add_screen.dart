import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/log_entry.dart';
import '../models/food.dart';
import '../services/log_service.dart';
import '../services/food_service.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../widgets/custom_alert.dart';
import 'settings_screen.dart';

class AiQuickAddScreen extends StatefulWidget {
  final String date;

  const AiQuickAddScreen({super.key, required this.date});

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

  @override
  void initState() {
    super.initState();
    _amountController.text = '100';
  }

  Future<void> _checkApiKeyAndTakePhoto() async {
    final hasApiKey = await SettingsService.hasGeminiApiKey();
    
    if (!hasApiKey) {
      _showApiKeyDialog();
      return;
    }
    
    _takePhoto();
  }

  void _showApiKeyDialog() {
    AlertHelper.showInfoAlert(
      context,
      title: 'API Key Required',
      message: 'You need to set up your Gemini AI API key to use this feature. Would you like to go to settings now?',
      actionButtonText: 'Settings',
      onActionPressed: () {
        Navigator.of(context).pop(); // Close the alert
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _nutritionData = null;
          _showPromptInput = true;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Camera Error',
          message: 'Failed to take photo: $e',
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _nutritionData = null;
          _showPromptInput = true;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Gallery Error',
          message: 'Failed to pick image: $e',
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
      final nutritionData = await AiService.analyzeFood(_selectedImage!, userPrompt: _promptController.text.trim());
      
      if (nutritionData != null && mounted) {
        setState(() {
          _nutritionData = nutritionData;
          _amountController.text = nutritionData['defaultPortionSize']?.toString() ?? '100';
        });
      }
    } catch (e) {
      if (mounted) {
        AlertHelper.showErrorAlert(
          context,
          title: 'Analysis Failed',
          message: 'Failed to analyze image. Please check your API key and try again.\n\nError: $e',
        );
        setState(() {
          _showPromptInput = true; // Allow user to try again
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _addToLog() async {
    if (_nutritionData == null) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      AlertHelper.showErrorAlert(
        context,
        title: 'Invalid Amount',
        message: 'Please enter a valid amount greater than 0.',
      );
      return;
    }

    try {
      int? foodId;
      
      // Only save to inventory if the user opted to do so
      if (_saveToInventory) {
        final foodService = FoodService();
        foodId = await foodService.insertFood(
          Food(
            name: _nutritionData!['name'] ?? 'AI Analyzed Food',
            calories: (_nutritionData!['calories'] ?? 0).toDouble(),
            protein: (_nutritionData!['protein'] ?? 0).toDouble(),
            carbs: (_nutritionData!['carbs'] ?? 0).toDouble(),
            fat: (_nutritionData!['fat'] ?? 0).toDouble(),
            defaultPortionSize: (_nutritionData!['defaultPortionSize'] ?? 100).toDouble(),
            portionDescription: _nutritionData!['portionDescription'] ?? '1 serving (100g)',
            type: 'simple',
          ),
        );
      } else {
        // Create a temporary food entry just for logging (won't be saved to inventory)
        final foodService = FoodService();
        foodId = await foodService.insertFood(
          Food(
            name: _nutritionData!['name'] ?? 'AI Analyzed Food',
            calories: (_nutritionData!['calories'] ?? 0).toDouble(),
            protein: (_nutritionData!['protein'] ?? 0).toDouble(),
            carbs: (_nutritionData!['carbs'] ?? 0).toDouble(),
            fat: (_nutritionData!['fat'] ?? 0).toDouble(),
            defaultPortionSize: (_nutritionData!['defaultPortionSize'] ?? 100).toDouble(),
            portionDescription: _nutritionData!['portionDescription'] ?? '1 serving (100g)',
            type: 'simple',
            isArchived: true, // Mark as archived so it doesn't show in inventory
          ),
        );
      }

      final logService = LogService();
      await logService.insertLogEntry(
        LogEntry(
          foodId: foodId,
          amount: amount,
          date: widget.date,
        ),
      );

      if (mounted) {
        String inventoryMessage = _saveToInventory 
            ? ' and saved to your inventory'
            : '';
        
        AlertHelper.showSuccessAlert(
          context,
          title: 'Added to Log!',
          message: '${_nutritionData!['name']} has been successfully added to your nutrition log$inventoryMessage.',
          actionButtonText: 'View Log',
          onActionPressed: () {
            Navigator.of(context).pop(); // Close the alert
            Navigator.pop(context, true); // Go back to previous screen
          },
        );
      }
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
  void dispose() {
    _amountController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Quick Scan',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo of your meal and AI will analyze its nutrition',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_selectedImage == null) ...[
                        _buildPhotoButtons(),
                      ] else ...[
                        _buildImagePreview(),
                        const SizedBox(height: 24),
                        if (_showPromptInput) ...[
                          _buildPromptInput(),
                        ] else if (_isAnalyzing) ...[
                          _buildAnalyzingIndicator(),
                        ] else if (_nutritionData != null) ...[
                          _buildNutritionResults(),
                          const SizedBox(height: 24),
                          _buildAmountInput(),
                          const SizedBox(height: 16),
                          _buildInventoryToggle(),
                          const SizedBox(height: 32),
                          _buildAddButton(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Take a photo of your meal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI will analyze the nutrition automatically',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _checkApiKeyAndTakePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing your meal...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is identifying the food and calculating nutrition',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionResults() {
    if (_nutritionData == null) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Analysis Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          
          // Food name
          Text(
            _nutritionData!['name'] ?? 'Unknown Food',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nutritional values per 100g',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 20),
          
          // Nutrition grid
          Row(
            children: [
              Expanded(
                child: _buildNutritionBox(
                  'Calories',
                  '${(_nutritionData!['calories'] ?? 0).toStringAsFixed(0)}',
                  'kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutritionBox(
                  'Protein',
                  '${(_nutritionData!['protein'] ?? 0).toStringAsFixed(1)}',
                  'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutritionBox(
                  'Carbs',
                  '${(_nutritionData!['carbs'] ?? 0).toStringAsFixed(1)}',
                  'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutritionBox(
                  'Fat',
                  '${(_nutritionData!['fat'] ?? 0).toStringAsFixed(1)}',
                  'g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBox(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    final portionSize = _nutritionData?['defaultPortionSize'] ?? 100;
    final portionDescription = _nutritionData?['portionDescription'] ?? '1 serving';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount to Add',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI estimated portion: $portionDescription',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Weight in grams',
              suffixText: 'g',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Enter the actual weight you consumed',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save to Inventory',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add this food to your inventory for future use',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _saveToInventory,
            onChanged: (value) {
              setState(() {
                _saveToInventory = value;
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _addToLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _saveToInventory ? 'Add to Log & Inventory' : 'Add to Log',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPromptInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe the Food (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add details about the food to help AI analyze it more accurately',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            keyboardType: TextInputType.text,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., "with rice flour, no sugar, keto"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _analyzeWithPrompt,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Analyze Food',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 