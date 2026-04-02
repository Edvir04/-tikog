import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tikog Requirement Prediction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E7D32),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final Map<String, List<double>> dimensionOptions = {
    "27 inches x 16 inches": [27.0, 16.0],
    "11 inches x 14 ½ inches": [11.0, 14.5],
    "12 inches x 7 ½ inches x 3 ½ inches": [12.0, 7.5, 3.5],
    "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)": [17.5, 2.0, 11.5, 11.5, 5.0, 6.0],
    "29 inches x 22 inches": [29.0, 22.0],
    "Custom": [0.0, 0.0]
  };

  final List<String> productTypes = [
    "Mat", "Bag", "Slippers", "Wallet", "Others"
  ];

  String selectedDimension = "27 inches x 16 inches";
  double length = 27.0;
  double width = 16.0;

  final TextEditingController quantityController = TextEditingController(text: "0");
  final TextEditingController customDim1Controller = TextEditingController();
  final TextEditingController customDim2Controller = TextEditingController();
  final TextEditingController customDim3Controller = TextEditingController();
  final TextEditingController customProductTypeController = TextEditingController();

  String selectedProductType = "Mat";

  bool isLoading = false;
  Map<String, dynamic>? predictionResult;
  String? errorMessage;

  @override
  void dispose() {
    quantityController.dispose();
    customDim1Controller.dispose();
    customDim2Controller.dispose();
    customDim3Controller.dispose();
    customProductTypeController.dispose();
    super.dispose();
  }

  void onDimensionChanged(String? value) {
    if (value != null) {
      setState(() {
        selectedDimension = value;
        if (value != "Custom") {
          final dims = dimensionOptions[value]!;
          length = dims[0];
          width = dims.length > 1 ? dims[1] : 0.0;
        }
      });
    }
  }

  // ============================================================
  // TIKOG STEM REFERENCE CONSTANTS
  // ============================================================
  static const double metersToInches = 39.3701;

  // Efficiency factor to account for real-world weaving conditions:
  //   - stem joining/overlapping when a stem is too short to span
  //     a product dimension
  //   - edge finishing
  // Note: There is NO trimming of width — stems are used at their
  // full natural flattened width. Flattening does not significantly
  // change the stem width.
  // A value of 1.10 means 10% extra stems are added.
  // Adjust this value as needed based on actual weaving experience.
  static const double efficiencyFactor = 1.10;

  // NOTE ON STEM WIDTHS:
  // The avgWidthIn values below (e.g., 0.156 inches) are very narrow.
  // This is intentional — tikog stems are naturally thin when dried
  // and flattened. Because the width is so small, the stem count
  // will be high. These values are based on measured averages of
  // flattened stems and should NOT be changed unless new field
  // measurements are taken.
  static const List<Map<String, dynamic>> leafCategories = [
    {
      'label': 'Category 1',
      'subtitle': '1.0 m – 1.75 m',
      'minLengthM': 1.0,
      'maxLengthM': 1.75,
      'avgLengthM': 1.375,
      'avgWidthIn': 0.156, // ~4 mm — natural flattened width
    },
    {
      'label': 'Category 2',
      'subtitle': '1.75 m – 2.5 m',
      'minLengthM': 1.75,
      'maxLengthM': 2.5,
      'avgLengthM': 2.125,
      'avgWidthIn': 0.188, // ~4.8 mm
    },
    {
      'label': 'Category 3',
      'subtitle': '2.5 m – 3.0 m+',
      'minLengthM': 2.5,
      'maxLengthM': 3.0,
      'avgLengthM': 2.75,
      'avgWidthIn': 0.219, // ~5.6 mm
    },
  ];

  /// Computes the product measurement for a Custom dimension.
  /// Accepts up to 3 dimension values; ignores any that are 0.
  /// - 1 dimension (1D): just Length (e.g., rope, strip)
  /// - 2 dimensions (2D): Length × Width (e.g., mat, fabric)
  /// - 3 dimensions (3D): Surface Area minus one open side
  ///   Formula: L×W + 2×L×H + 2×W×H  (5 faces, open top)
  ///   In real-world use, 3D products (baskets, boxes) always have
  ///   one open side (e.g., the top), so we exclude it.
  double _computeCustomArea(List<double> dims) {
    switch (dims.length) {
      case 1:
        return dims[0]; // 1D: just length (linear)
      case 2:
        return dims[0] * dims[1]; // 2D: flat area
      case 3:
        // 3D: 5-FACE SURFACE AREA (open top excluded)
        // Full box = 2×(L×W + L×H + W×H) = 6 faces
        // Minus open top (L×W) = 5 faces
        // = L×W + 2×L×H + 2×W×H
        double l = dims[0], w = dims[1], h = dims[2];
        return (l * w) + 2 * (l * h) + 2 * (w * h);
      default:
        return 0.0;
    }
  }

  Future<void> makePrediction() async {
    setState(() {
      isLoading = true;
      predictionResult = null;
      errorMessage = null;
    });

    try {
      double productArea;

      if (selectedDimension == "Custom") {
        // Gather all 3 dimension fields, filter out zeros
        List<double> customDims = [
          double.tryParse(customDim1Controller.text) ?? 0.0,
          double.tryParse(customDim2Controller.text) ?? 0.0,
          double.tryParse(customDim3Controller.text) ?? 0.0,
        ].where((d) => d > 0).toList();

        if (customDims.isEmpty) {
          throw Exception("Please enter at least one dimension greater than 0.");
        }

        productArea = _computeCustomArea(customDims);
      } else {
        // Preset dimensions
        productArea = length * width;

        // Special case overrides for complex presets
        if (selectedDimension == "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)") {
          double bodyArea = 17.5 * 2.0;
          double packetArea = 11.5 * 11.5;
          double sideArea = 5.0 * 6.0;
          productArea = bodyArea + packetArea + sideArea;
        } else if (selectedDimension == "12 inches x 7 ½ inches x 3 ½ inches") {
          double baseArea = 12.0 * 7.5;
          double longWallsArea = 2 * (12.0 * 3.5);
          double shortWallsArea = 2 * (7.5 * 3.5);
          productArea = baseArea + longWallsArea + shortWallsArea;
        }
      }

      // Parse single quantity
      final int quantity = int.tryParse(quantityController.text.trim()) ?? 0;
      if (quantity <= 0) {
        throw Exception("Please enter a valid quantity greater than 0.");
      }

      // ==========================================================
      // PRODUCT SIDES
      // ==========================================================
      String displayProductType = selectedProductType;
      Map<String, int> productSides = {
        "Mat": 1, "Bag": 2, "Slippers": 2, "Wallet": 2, "Others": 1
      };
      int sides = productSides[selectedProductType] ?? 1;

      // If "Others", use the custom product type name for display
      if (selectedProductType == "Others") {
        String customName = customProductTypeController.text.trim();
        if (customName.isNotEmpty) {
          displayProductType = customName;
        } else {
          displayProductType = "Others";
        }
      }

      // ==========================================================
      // DETERMINISTIC PREDICTION LOGIC
      // ==========================================================
      // For each stem category, compute:
      //   rawStems = (product area × number of sides) / stem coverage area
      //   adjustedStems = rawStems × efficiencyFactor
      // where:
      //   stem coverage area = avg stem length (in) × avg stem width (in)
      //   efficiencyFactor accounts for stem joining/overlap and edge finishing
      // ==========================================================
      double totalProductArea = productArea * sides;

      List<Map<String, dynamic>> categoryResults = [];

      for (var cat in leafCategories) {
        double catAvgLengthIn = (cat['avgLengthM'] as double) * metersToInches;
        double catAvgWidthIn = cat['avgWidthIn'] as double;
        double catCoverage = catAvgLengthIn * catAvgWidthIn; // in² per stem

        // Raw stem count based on pure area division
        double rawPerProduct = totalProductArea / (catCoverage > 0 ? catCoverage : 1.0);
        if (rawPerProduct < 1) rawPerProduct = 1.0;

        // Apply efficiency factor for stem joining/overlap and edge finishing
        double catPerProductExact = rawPerProduct * efficiencyFactor;

        double totalForCategory = catPerProductExact * quantity;

        categoryResults.add({
          'label': cat['label'],
          'subtitle': cat['subtitle'],
          'avgLengthM': cat['avgLengthM'],
          'avgWidthIn': cat['avgWidthIn'],
          'coverageIn2': catCoverage,
          'leavesPerProduct': catPerProductExact,
          'totalLeaves': totalForCategory,
        });
      }

      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        predictionResult = {
          "categories": categoryResults,
          "info": {
            "product_area": productArea,
            "number_of_sides": sides,
            "total_quantity": quantity,
          },
          "details": {
            "dimension": selectedDimension,
            "product_type": displayProductType,
          },
        };
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Tikog Requirement Prediction App",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the following details to predict the required Tikog for your product:",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // ── Dimension Dropdown ──
            _buildLabel("Dimension"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedDimension,
                  items: dimensionOptions.keys.map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                  onChanged: onDimensionChanged,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Custom Dimensions (up to 3 fields) ──
            if (selectedDimension == "Custom")
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Fill in only the fields you need. Leave the rest empty or 0.",
                    style: TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Length (inches)"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: customDim1Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Width (inches)"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: customDim2Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Height (inches)"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: customDim3Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hint about how dimensions are interpreted
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "💡 How it works:\n"
                      "• Length only — for straight items like strips or rope\n"
                      "• Length + Width — for flat items like mats or fabric\n"
                      "• Length + Width + Height — for 3D items like boxes or baskets",
                      style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.6),
                    ),
                  ),
                ],
              )
            else
              _buildPresetDimensionDisplay(),
            const SizedBox(height: 24),

            // ── Quantity (single value only) ──
            _buildLabel("Quantity"),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // ── Product Type ──
            _buildLabel("Product Type"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedProductType,
                  items: productTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedProductType = val);
                  },
                ),
              ),
            ),

            // ── Custom product type text field when "Others" is selected ──
            if (selectedProductType == "Others") ...[
              const SizedBox(height: 12),
              _buildLabel("Specify Product Type"),
              const SizedBox(height: 8),
              TextField(
                controller: customProductTypeController,
                decoration: const InputDecoration(
                  hintText: "e.g. Placemat, Coaster, Fan...",
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Predict Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : makePrediction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Predict",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Error Message ──
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade900),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),

            // ── Results Section ──
            if (predictionResult != null) _buildResultSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  /// Builds contextual dimension display for preset (non-Custom) selections.
  Widget _buildPresetDimensionDisplay() {
    if (selectedDimension == "12 inches x 7 ½ inches x 3 ½ inches") {
      // 3D preset: show Length, Width, Height
      final dims = dimensionOptions[selectedDimension]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Length: ${dims[0]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("Width: ${dims[1]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("Height: ${dims[2]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
            "⬡ Uses 5-face surface area (open top excluded)",
            style: TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
          ),
        ],
      );
    } else if (selectedDimension == "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)") {
      // Composite preset: show each panel
      final dims = dimensionOptions[selectedDimension]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Body: ${dims[0]} × ${dims[1]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("Packet: ${dims[2]} × ${dims[3]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("Side: ${dims[4]} × ${dims[5]} inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
            "⬡ Total area = sum of all panels",
            style: TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
          ),
        ],
      );
    } else {
      // Standard 2D preset: show Length and Width
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Length: $length inches", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("Width: $width inches", style: const TextStyle(fontSize: 14)),
        ],
      );
    }
  }

  /// Returns a contextual product area label for the results section.
  String _getProductAreaLabel() {
    if (predictionResult == null) return "";
    final area = (predictionResult!['info']['product_area'] as double).toStringAsFixed(2);
    final dimension = predictionResult!['details']['dimension'] as String;

    if (dimension == "12 inches x 7 ½ inches x 3 ½ inches") {
      return "Surface Area (5 faces): $area in²";
    } else if (dimension == "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)") {
      return "Total Panel Area: $area in²";
    } else {
      return "Product Area: $area in²";
    }
  }

  Widget _buildResultSection() {
    final categories = predictionResult!['categories'] as List<Map<String, dynamic>>;
    final info = predictionResult!['info'] as Map<String, dynamic>;
    final details = predictionResult!['details'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Prediction Results by Leaf Size",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Only leaves ≥ 1.0 m are included. Each category shows the predicted tikog leaves needed if your harvest consists of that leaf size range.",
          style: TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        ...categories.map((cat) => _buildPredictionCard(cat, info)),
        const SizedBox(height: 20),

        _buildSectionHeader("Product Details"),
        const SizedBox(height: 10),
        _buildResultText("Dimension: ${details['dimension']}"),
        _buildResultText(_getProductAreaLabel()),
        _buildResultText("Product Type: ${details['product_type']}"),
        _buildResultText("Total Quantity: ${info['total_quantity']}"),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> cat, Map<String, dynamic> info) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${cat['label']}:  ${cat['subtitle']}",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${_roundLeaves(cat['totalLeaves'] as double)} tikog leaves required",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${_formatLeavesPerProduct(cat['leavesPerProduct'] as double)} leaves/product × ${info['total_quantity']} products",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "Avg leaf: ${(cat['avgLengthM'] as double).toStringAsFixed(2)} m × ${(cat['avgWidthIn'] as double).toStringAsFixed(3)}\"  •  "
            "Coverage: ${(cat['coverageIn2'] as double).toStringAsFixed(2)} in²/leaf",
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildResultText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }

  // ============================================================
  // ROUNDING HELPER
  // ============================================================
  // Rounding rule:
  //   - If decimal part >= 0.5 → round UP to next whole number
  //   - If decimal part <= 0.4 → round DOWN (floor)
  // Dart's .round() implements this standard behavior.
  // ============================================================

  /// Applies the standard rounding rule to a leaf count.
  int _roundLeaves(double value) {
    return value.round();
  }

  /// Formats per-product leaves for display using standard rounding.
  String _formatLeavesPerProduct(double value) {
    return '${_roundLeaves(value)}';
  }
}
