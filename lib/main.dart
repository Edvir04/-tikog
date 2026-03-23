import 'package:flutter/material.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E7D32), // Green highlight for prediction
          surface: Color(0xFF1E1E1E), // Slightly lighter for cards/inputs
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
    "12 inches x 7 ½ inches x 3 ½ inches": [12.0, 7.5],
    "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)": [17.5, 2.0],
    "29 inches x 22 inches": [29.0, 22.0],
    "Custom": [0.0, 0.0]
  };

  final List<String> productTypes = [
    "Mat", "Bag", "Slippers", "Wallet", "Others"
  ];

  final List<String> salesTrends = [
    "Increasing", "Stable", "Decreasing"
  ];

  String selectedDimension = "27 inches x 16 inches";
  double length = 27.0;
  double width = 16.0;

  final TextEditingController quantityController = TextEditingController(text: "0");
  final TextEditingController customLengthController = TextEditingController();
  final TextEditingController customWidthController = TextEditingController();

  String selectedProductType = "Mat";
  String selectedSalesTrend = "Increasing";

  bool isLoading = false;
  Map<String, dynamic>? predictionResult;
  String? errorMessage;

  @override
  void dispose() {
    quantityController.dispose();
    customLengthController.dispose();
    customWidthController.dispose();
    super.dispose();
  }

  void onDimensionChanged(String? value) {
    if (value != null) {
      setState(() {
        selectedDimension = value;
        if (value != "Custom") {
          length = dimensionOptions[value]![0];
          width = dimensionOptions[value]![1];
        } else {
          length = double.tryParse(customLengthController.text) ?? 0.0;
          width = double.tryParse(customWidthController.text) ?? 0.0;
        }
      });
    }
  }

  // ============================================================
  // TIKOG LEAF REFERENCE CONSTANTS
  // ============================================================
  // Minimum harvestable length: 1.0 meter
  // Leaf length range: 1.0 to 3.0 meters
  // Leaf width range: 1/8 inch (0.125") to 1/4 inch (0.25")
  static const double minHarvestableLengthM = 1.0;
  static const double maxLeafLengthM = 3.0;
  static const double minLeafWidthIn = 0.125; // 1/8 inch
  static const double maxLeafWidthIn = 0.25;  // 1/4 inch
  static const double metersToInches = 39.3701;

  // Leaf size categories — only leaves >= 1.0m are harvestable
  static const List<Map<String, dynamic>> leafCategories = [
    {
      'label': 'Category 1',
      'subtitle': '1.0 m – 1.75 m',
      'minLengthM': 1.0,
      'maxLengthM': 1.75,
      'avgLengthM': 1.375,
      'avgWidthIn': 0.156, // narrower leaves typical at this size
    },
    {
      'label': 'Category 2',
      'subtitle': '1.75 m – 2.5 m',
      'minLengthM': 1.75,
      'maxLengthM': 2.5,
      'avgLengthM': 2.125,
      'avgWidthIn': 0.188, // mid-range width
    },
    {
      'label': 'Category 3',
      'subtitle': '2.5 m – 3.0 m+',
      'minLengthM': 2.5,
      'maxLengthM': 3.0,
      'avgLengthM': 2.75,
      'avgWidthIn': 0.219, // wider leaves at longer sizes
    },
  ];

  Future<void> makePrediction() async {
    setState(() {
      isLoading = true;
      predictionResult = null;
      errorMessage = null;
    });

    try {
      if (selectedDimension == "Custom") {
        length = double.tryParse(customLengthController.text) ?? 0.0;
        width = double.tryParse(customWidthController.text) ?? 0.0;
      }

      final String quantityText = quantityController.text;
      final List<int> quantities = quantityText
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();

      if (quantities.isEmpty || quantities.any((q) => q <= 0)) {
        throw Exception("Please enter valid quantities separated by commas.");
      }
      if (length <= 0 || width <= 0) {
        throw Exception("Length and Width must be greater than 0.");
      }

      // ==========================================================
      // 1. PRODUCT SIDES
      // ==========================================================
      Map<String, int> productSides = {
        "Mat": 1, "Bag": 2, "Slippers": 2, "Wallet": 2, "Others": 1
      };
      int sides = productSides[selectedProductType] ?? 1;

      // ==========================================================
      // 2. DETERMINISTIC PREDICTION LOGIC (from APP1.py)
      // ==========================================================
      double productArea = length * width; // in²

      // Special case for complex dimension string
      if (selectedDimension == "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)") {
        double bodyArea = 17.5 * 2.0;      // 35.0
        double packetArea = 11.5 * 11.5;   // 132.25
        double sideArea = 5.0 * 6.0;       // 30.0
        productArea = bodyArea + packetArea + sideArea; // 197.25
      } else if (selectedDimension == "12 inches x 7 ½ inches x 3 ½ inches") {
        // Surface area for an open 3D rectangular box (Base + 4 Walls)
        // Length = 12.0, Width = 7.5, Height/Depth = 3.5
        double baseArea = 12.0 * 7.5;              // 90.0
        double longWallsArea = 2 * (12.0 * 3.5);   // 84.0
        double shortWallsArea = 2 * (7.5 * 3.5);   // 52.5
        productArea = baseArea + longWallsArea + shortWallsArea; // 226.5
      }

      double baseTikogPerSide = productArea / 2.0;

      // Apply product sides
      double tikogPerProduct = baseTikogPerSide * sides;

      // ==========================================================
      // 3. SALES TREND ADJUSTMENT (deterministic)
      // ==========================================================
      double trendMultiplier;
      switch (selectedSalesTrend) {
        case "Increasing":
          trendMultiplier = 1.15;
          break;
        case "Decreasing":
          trendMultiplier = 0.85;
          break;
        default:
          trendMultiplier = 1.00;
      }

      double adjustedPerProduct = tikogPerProduct * trendMultiplier;

      // ==========================================================
      // 4. APPLY QUANTITY
      // ==========================================================
      int totalQuantity = quantities.fold(0, (sum, item) => sum + item);
      if (totalQuantity <= 0) {
        throw Exception("Total quantity must be greater than 0");
      }

      // ==========================================================
      // 5. PER-CATEGORY PREDICTION
      // ==========================================================
      // Each category adjusts the count based on leaf coverage area.
      // Shorter/narrower leaves → more leaves needed to cover same area.
      // Longer/wider leaves → fewer leaves needed.
      //
      // We compute a coverage ratio: how much area does the average leaf
      // in each category cover, relative to the overall average leaf.
      double avgLeafLengthIn = ((minHarvestableLengthM + maxLeafLengthM) / 2.0) * metersToInches;
      double avgLeafWidthIn = (minLeafWidthIn + maxLeafWidthIn) / 2.0;
      double avgLeafCoverage = avgLeafLengthIn * avgLeafWidthIn; // in²

      List<Map<String, dynamic>> categoryResults = [];

      for (var cat in leafCategories) {
        double catAvgLengthIn = (cat['avgLengthM'] as double) * metersToInches;
        double catAvgWidthIn = cat['avgWidthIn'] as double;
        double catCoverage = catAvgLengthIn * catAvgWidthIn; // in² per leaf

        // Ratio: smaller leaves have coverage < average → ratio > 1 → more leaves
        double coverageRatio = avgLeafCoverage / (catCoverage > 0 ? catCoverage : 1.0);

        // Exact fractional leaves per product for this category
        double catPerProductExact = adjustedPerProduct * coverageRatio;

        // Requirement per product rounded UP (as requested to ensure enough material)
        int perProduct = catPerProductExact.ceil();
        if (perProduct < 1) perProduct = 1;

        // Apply total quantity to the rounded per-product number
        int totalForCategory = perProduct * totalQuantity;

        categoryResults.add({
          'label': cat['label'],
          'subtitle': cat['subtitle'],
          'avgLengthM': cat['avgLengthM'],
          'avgWidthIn': cat['avgWidthIn'],
          'coverageIn2': catCoverage,
          'leavesPerProduct': perProduct,
          'totalLeaves': totalForCategory,
        });
      }

      // Brief UI delay for feedback
      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        predictionResult = {
          "categories": categoryResults,
          "info": {
            "product_area": productArea,
            "number_of_sides": sides,
            "trend_multiplier": trendMultiplier,
            "total_quantity": totalQuantity,
          },
          "details": {
            "dimension": selectedDimension,
            "length": length,
            "width": width,
            "product_type": selectedProductType,
            "sales_trend": selectedSalesTrend,
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
            
            // Dimension Dropdown
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

            // Length and Width Fields
            if (selectedDimension == "Custom")
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Length (inches)"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: customLengthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Width (inches)"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: customWidthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Length: $length inches", style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Width: $width inches", style: const TextStyle(fontSize: 14)),
                ],
              ),
            const SizedBox(height: 24),

            // Quantity
            _buildLabel("Quantity (Enter multiple quantities separated by commas)"),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            // Product Type
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
            const SizedBox(height: 24),

            // Sales Trend
            _buildLabel("Sales Trend"),
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
                  value: selectedSalesTrend,
                  items: salesTrends.map((String trend) {
                    return DropdownMenuItem<String>(
                      value: trend,
                      child: Text(trend),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedSalesTrend = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Predict Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : makePrediction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary, // Green
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

            // Error Message
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

            // Results Section
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

  Widget _buildResultSection() {
    final categories = predictionResult!['categories'] as List<Map<String, dynamic>>;
    final info = predictionResult!['info'] as Map<String, dynamic>;
    final details = predictionResult!['details'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title ──
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

        // ── Three Category Prediction Cards ──
        ...categories.map((cat) => _buildPredictionCard(cat, info)),
        const SizedBox(height: 20),

        // ── Product Details ──
        _buildSectionHeader("Product Details"),
        const SizedBox(height: 10),
        _buildResultText("Dimension: ${details['dimension']}"),
        _buildResultText("Length: ${details['length']} inches  •  Width: ${details['width']} inches"),
        _buildResultText("Product Type: ${details['product_type']}"),
        _buildResultText("Sales Trend: ${details['sales_trend']}"),
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
          // Category header
          Text(
            "${cat['label']}:  ${cat['subtitle']}",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 8),
          // Main prediction number
          Text(
            "${cat['totalLeaves']} tikog leaves required",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          // Supporting details
          Text(
            "${cat['leavesPerProduct']} leaves/product × ${info['total_quantity']} products",
            style: const TextStyle(fontSize: 12, color: Colors.white70),
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
}
