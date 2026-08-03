import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../models/food.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'add_food_screen.dart';

enum _ScanStatus { scanning, processing, notFound, error }

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  _ScanStatus _status = _ScanStatus.scanning;
  String _message = '';
  String? _lastBarcode;

  Future<void> _processBarcode(String barcode) async {
    if (_status == _ScanStatus.processing) return;
    setState(() {
      _status = _ScanStatus.processing;
      _lastBarcode = barcode;
    });

    try {
      final configuration = ProductQueryConfiguration(
        barcode,
        language: OpenFoodFactsLanguage.ENGLISH,
        fields: [ProductField.ALL],
        version: ProductQueryVersion.v3,
      );

      final result = await OpenFoodAPIClient.getProductV3(configuration);

      if (result.status == ProductResultV3.statusSuccess &&
          result.product != null) {
        final product = result.product!;
        final macros = _extractNutrition(product);

        // Guard: if OFF genuinely has no usable nutrition, tell the user
        // instead of creating an all-zero food.
        if (macros.allZero) {
          setState(() {
            _status = _ScanStatus.notFound;
            _message =
                '"${product.productName ?? 'This product'}" was found, but it '
                'has no nutrition data on OpenFoodFacts. You can add it manually.';
          });
          return;
        }

        final food = Food(
          name: product.productName ?? 'Unknown Product',
          calories: macros.calories,
          fat: macros.fat,
          carbs: macros.carbs,
          protein: macros.protein,
          type: 'simple',
          defaultPortionSize: macros.servingSize,
          portionDescription: macros.portionDescription,
          hasServing: macros.hasServing,
        );

        if (mounted) {
          // Pause the camera while the add screen is on top.
          await controller.stop();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddFoodScreen(food: food)),
          );
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _status = _ScanStatus.notFound;
          _message =
              'No product matched barcode $barcode. It may not be on '
              'OpenFoodFacts yet — you can add it manually.';
        });
      }
    } catch (e) {
      debugPrint('Barcode lookup failed: $e');
      setState(() {
        _status = _ScanStatus.error;
        _message =
            'We couldn\'t reach the food database. Check your connection and '
            'try again, or add this item manually.';
      });
    }
  }

  /// Robust nutrition extraction with kcal/kJ and per-serving fallbacks, so we
  /// don't hand back all-zero values when OFF stores data in a different field.
  _Macros _extractNutrition(Product product) {
    double servingSize = 100.0;
    String portionDescription = '100g';
    bool hasServing = false;

    if (product.servingSize != null && product.servingSize!.isNotEmpty) {
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(product.servingSize!);
      if (match != null) {
        servingSize = double.tryParse(match.group(1) ?? '') ?? 100.0;
        portionDescription = product.servingSize!;
        hasServing = true;
      }
    }

    final n = product.nutriments;
    if (n == null) {
      return _Macros(0, 0, 0, 0, servingSize, portionDescription, false);
    }

    double energyFor(PerSize size) {
      final kcal = n.getValue(Nutrient.energyKCal, size);
      if (kcal != null && kcal > 0) return kcal;
      final kj = n.getComputedKJ(size) ?? 0.0;
      return kj > 0 ? NutrimentsHelper.fromKJtoKCal(kj) : 0.0;
    }

    double calories = energyFor(PerSize.oneHundredGrams);
    double fat = n.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0;
    double carbs =
        n.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0;
    double protein = n.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0;

    // Fallback: derive per-100 from per-serving values when the 100 g block is
    // empty but a serving block exists.
    if (calories == 0 && fat == 0 && carbs == 0 && protein == 0) {
      final sCal = energyFor(PerSize.serving);
      final sFat = n.getValue(Nutrient.fat, PerSize.serving) ?? 0.0;
      final sCarbs =
          n.getValue(Nutrient.carbohydrates, PerSize.serving) ?? 0.0;
      final sProt = n.getValue(Nutrient.proteins, PerSize.serving) ?? 0.0;
      if (servingSize > 0 &&
          (sCal > 0 || sFat > 0 || sCarbs > 0 || sProt > 0)) {
        final factor = 100 / servingSize;
        calories = sCal * factor;
        fat = sFat * factor;
        carbs = sCarbs * factor;
        protein = sProt * factor;
      }
    }

    return _Macros(
      calories,
      fat,
      carbs,
      protein,
      servingSize,
      portionDescription,
      hasServing,
    );
  }

  void _rescan() {
    setState(() {
      _status = _ScanStatus.scanning;
      _message = '';
    });
  }

  void _addManually() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFoodScreen()),
    ).then((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: PageAppBar(
        title: 'Scan barcode',
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                final on = state == TorchState.on;
                return Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: on ? scheme.primary : scheme.onSurfaceVariant,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space8),
              Text(
                'Point your camera at a product barcode',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              _cameraWindow(context),
              const SizedBox(height: AppTheme.space24),
              if (_status == _ScanStatus.notFound ||
                  _status == _ScanStatus.error)
                _resultPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraWindow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A wide, landscape scan window rather than a fullscreen camera.
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_status == _ScanStatus.scanning ||
                _status == _ScanStatus.processing)
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    if (barcode.rawValue != null) {
                      _processBarcode(barcode.rawValue!);
                      break;
                    }
                  }
                },
              )
            else
              Container(color: scheme.surfaceContainerHigh),

            // Framing guide.
            IgnorePointer(
              child: Center(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space24,
                    vertical: AppTheme.space24,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),

            if (_status == _ScanStatus.processing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = _status == _ScanStatus.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.search_off_rounded,
            color: isError ? scheme.error : scheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rescan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Rescan'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addManually,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Add manually'),
                ),
              ),
            ],
          ),
          if (_lastBarcode != null) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              'Barcode: $_lastBarcode',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
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

class _Macros {
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final double servingSize;
  final String portionDescription;
  final bool hasServing;

  _Macros(
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
    this.servingSize,
    this.portionDescription,
    this.hasServing,
  );

  bool get allZero =>
      calories == 0 && fat == 0 && carbs == 0 && protein == 0;
}
