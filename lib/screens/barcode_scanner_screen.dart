import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../models/food.dart';
import 'add_food_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _processBarcode(String barcode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Query OpenFoodFacts using the existing configuration
      final ProductQueryConfiguration configuration = ProductQueryConfiguration(
        barcode,
        language: OpenFoodFactsLanguage.ENGLISH,
        fields: [ProductField.ALL],
        version: ProductQueryVersion.v3,
      );
      
      final ProductResultV3 result = await OpenFoodAPIClient.getProductV3(configuration);

      if (result.status == ProductResultV3.statusSuccess && result.product != null) {
        final product = result.product!;
        
        // Extract nutrition values
        double calories = 0, fat = 0, carbs = 0, protein = 0;
        double servingSize = 100.0;
        String portionDescription = "100g";

        if (product.servingSize != null && product.servingSize!.isNotEmpty) {
          final RegExp regExp = RegExp(r'(\d+(\.\d+)?)');
          final match = regExp.firstMatch(product.servingSize!);
          if (match != null) {
            servingSize = double.tryParse(match.group(1) ?? "") ?? 100.0;
            portionDescription = product.servingSize!;
          }
        }
        
        if (product.nutriments != null) {
          final nutriments = product.nutriments!;

          final kJValue = nutriments.getComputedKJ(PerSize.oneHundredGrams) ?? 0.0;
          calories = NutrimentsHelper.fromKJtoKCal(kJValue);
          

          // Extract other macronutrients
          fat = nutriments.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0;
          carbs = nutriments.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0;
          protein = nutriments.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0;
        }
        
        // Create Food object from product data with fromBarcode flag set to true
        final food = Food(
          name: product.productName ?? 'Unknown Product',
          calories: calories,
          fat: fat,
          carbs: carbs,
          protein: protein,
          type: 'simple',
          defaultPortionSize: servingSize,
          portionDescription: portionDescription,
        );

        // Navigate to AddFoodScreen with the scanned data
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFoodScreen(
                food: food,
              ),
            ),
          ).then((_) {
            Navigator.pop(context, true);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found in database')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Scan Barcode', 
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return Icon(Icons.flash_off, 
                      color: Theme.of(context).colorScheme.primary);
                  case TorchState.on:
                    return Icon(Icons.flash_on, 
                      color: Theme.of(context).colorScheme.primary);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processBarcode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}