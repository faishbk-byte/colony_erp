import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PremiumColonyErpApp());
}

class PremiumColonyErpApp extends StatelessWidget {
  const PremiumColonyErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Colony ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Helvetica',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      ),
      home: const MainShellScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. SLEEK NAVIGATION SHELL & DATABASE HANDLER
// ---------------------------------------------------------------------------
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});
  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  // Global Project State
  double _siteCashFloat = 25000.00;
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _plots = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // --- OFFLINE DATABASE LOGIC ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Float
    _siteCashFloat = prefs.getDouble('siteCashFloat') ?? 25000.00;
    
    // Load Vouchers
    final String? vouchersJson = prefs.getString('vouchers');
    if (vouchersJson != null) {
      final List decoded = jsonDecode(vouchersJson);
      _vouchers = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // Load Plots
    final String? plotsJson = prefs.getString('plots');
    if (plotsJson != null) {
      final List decodedPlots = jsonDecode(plotsJson);
      _plots = decodedPlots.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      // Default plot if memory is empty
      _plots = [
        {'plotNo': 'A-1', 'widthFt': 30.0, 'depthFt': 45.0, 'areaSqYd': 150.0, 'status': 'OPEN', 'payments': []}
      ];
    }

    setState(() { _isLoading = false; });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('siteCashFloat', _siteCashFloat);
    await prefs.setString('vouchers', jsonEncode(_vouchers));
    await prefs.setString('plots', jsonEncode(_plots));
  }

  void _updatePlots(List<Map<String, dynamic>> updatedPlots) {
    setState(() { _plots = updatedPlots; });
    _saveData();
  }

  void _addNewVoucher(Map<String, dynamic> voucher) {
    setState(() {
      final double amt = voucher['amount'] as double;
      if (voucher['mode'] == 'Cash in Hand') {
        _siteCashFloat -= amt;
      }
      _vouchers.insert(0, voucher);
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> screens = [
      DynamicPlotInventoryTab(plots: _plots, onPlotsUpdated: _updatePlots),
      VouchersTab(currentFloat: _siteCashFloat, vouchers: _vouchers, onAddVoucher: _addNewVoucher),
      const ContractorStatementTab(),
      const MarginCompassTab(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: screens),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navItem(Icons.architecture, 'Plots', 0),
                  _navItem(Icons.receipt_long, 'Vouchers', 1),
                  _navItem(Icons.handshake_outlined, 'Vendors', 2),
                  _navItem(Icons.explore_outlined, 'Compass', 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. PREMIUM PLOT LEDGER
// ---------------------------------------------------------------------------
class DynamicPlotInventoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> plots;
  final Function(List<Map<String, dynamic>>) onPlotsUpdated;

  const DynamicPlotInventoryTab({super.key, required this.plots, required this.onPlotsUpdated});

  @override
  State<DynamicPlotInventoryTab> createState() => _DynamicPlotInventoryTabState();
}

class _DynamicPlotInventoryTabState extends State<DynamicPlotInventoryTab> {
  void _updateState() => widget.onPlotsUpdated(widget.plots);

  void _showCarvePlotModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CarvePlotSheet(onSave: (plot) {
        widget.plots.insert(0, plot);
        _updateState();
        Navigator.pop(ctx);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    int soldCount = widget.plots.where((p) => p['status'] == 'SOLD').length;
    double totalRevenue = widget.plots.where((p) => p['status'] == 'SOLD').fold(0.0, (sum, p) => sum + (p['totalAmount'] ?? 0.0));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('THE IMPERIAL ENCLAVE', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  const Text('Master Ledger', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _headerStat('Units Sold', '$soldCount', Icons.check_circle),
                      _headerStat('Gross Value', '₹${_fmt(totalRevenue)}', Icons.account_balance_wallet),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final plot = widget.plots[index];
                  bool isSold = plot['status'] == 'SOLD';

                  return GestureDetector(
                    onTap: () => isSold ? _showClientLedger(plot) : _showSellPlotModal(plot),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            Container(width: 6, height: 110, color: isSold ? Colors.red.shade500 : const Color(0xFF059669)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(plot['plotNo'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: isSold ? Colors.red.shade50 : const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSold ? Colors.red.shade200 : const Color(0xFFA7F3D0))),
                                          child: Text(plot['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSold ? Colors.red.shade700 : const Color(0xFF059669))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${plot['areaSqYd'].toStringAsFixed(1)} Sq.Yd.  •  ${plot['widthFt']} x ${plot['depthFt']} ft', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    if (isSold) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('👤 ${plot['buyerName']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                                          Text('Ledger ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade700)),
                                        ],
                                      )
                                    ] else ...[
                                      const SizedBox(height: 12),
                                      const Text('Tap to carve or sell plot ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669))),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: widget.plots.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFD97706),
          foregroundColor: Colors.white,
          elevation: 6,
          onPressed: _showCarvePlotModal,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFFD97706), size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])
      ],
    );
  }

  void _showClientLedger(Map<String, dynamic> plot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          List payments = plot['payments'] ?? [];
          double totalAmount = plot['totalAmount'] ?? 0.0;
          double totalPaid = payments.fold(0.0, (sum, p) => sum + (p['amount'] ?? 0.0));
          double balance = totalAmount - totalPaid;
          
          DateTime deadline = DateTime.parse(plot['deadlineDate']);
          int daysLeft = deadline.difference(DateTime.now()).inDays;

          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              children: [
                Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('PLOT ${plot['plotNo']}', style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          Text(daysLeft >= 0 ? '$daysLeft Days Left' : 'OVERDUE', style: TextStyle(color: daysLeft >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('₹${_fmt(balance)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                      const Text('Remaining Balance Due', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _darkStat('Total Deal', '₹${_fmt(totalAmount)}'),
                          _darkStat('Received', '₹${_fmt(totalPaid)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CLIENT PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(plot['buyerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('📞 ${plot['buyerPhone']}   |   📍 ${plot['buyerAddress']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('PAN: ${plot['buyerPan']}   |   Aadhaar: ${plot['buyerAadhaar']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Divider()),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: payments.length,
                    itemBuilder: (context, i) {
                      final p = payments[i];
                      DateTime pDate = DateTime.parse(p['date']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.download_done_rounded, color: Color(0xFF059669), size: 20)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['mode'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Ref: ${p['ref']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+ ₹${_fmt(p['amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669))),
                                Text("${pDate.day}/${pDate.month}/${pDate.year}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: balance <= 0 ? null : () {
                        Navigator.pop(ctx);
                        _showPaymentModal(plot);
                      },
                      child: const Text('RECORD NEW PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  void _showPaymentModal(Map<String, dynamic> plot) {
    final amtController = TextEditingController();
    final refController = TextEditingController();
    String mode = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEW PAYMENT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _premiumInput(amtController, 'Amount Received (₹)', isNumber: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: mode,
              decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              items: ['Cash', 'UPI', 'RTGS', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => mode = val!,
            ),
            const SizedBox(height: 12),
            _premiumInput(refController, 'Reference / Cheque No.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (amtController.text.isEmpty) return;
                  if (plot['payments'] == null) plot['payments'] = [];
                  plot['payments'].insert(0, {
                    'amount': double.parse(amtController.text),
                    'mode': mode,
                    'ref': refController.text.isEmpty ? 'N/A' : refController.text,
                    'date': DateTime.now().toIso8601String()
                  });
                  _updateState();
                  Navigator.pop(ctx);
                },
                child: const Text('SAVE PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkStat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))]);
  }

  void _showSellPlotModal(Map<String, dynamic> plot) {
    final buyerController = TextEditingController();
    final phoneController = TextEditingController();
    final aadhaarController = TextEditingController();
    final panController = TextEditingController();
    final rateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              const Text('NEW SALE AGREEMENT', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('Plot ${plot['plotNo']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text('${plot['areaSqYd'].toStringAsFixed(1)} Sq. Yd.', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 30),
              
              _premiumInput(buyerController, 'Client Full Name'),
              const SizedBox(height: 16),
              _premiumInput(phoneController, 'Phone Number', isNumber: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _premiumInput(aadhaarController, 'Aadhaar (Optional)')),
                  const SizedBox(width: 16),
                  Expanded(child: _premiumInput(panController, 'PAN (Optional)')),
                ],
              ),
              const SizedBox(height: 16),
              _premiumInput(rateController, 'Selling Rate (₹/Sq.Yd)', isNumber: true),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () {
                    if (buyerController.text.isEmpty || rateController.text.isEmpty) return;
                    plot['status'] = 'SOLD';
                    plot['buyerName'] = buyerController.text;
                    plot['buyerPhone'] = phoneController.text;
                    plot['buyerAadhaar'] = aadhaarController.text.isEmpty ? 'Not Provided' : aadhaarController.text;
                    plot['buyerPan'] = panController.text.isEmpty ? 'Not Provided' : panController.text;
                    plot['buyerAddress'] = 'TBD';
                    plot['soldDate'] = DateTime.now().toIso8601String();
                    plot['soldRate'] = double.parse(rateController.text);
                    plot['totalAmount'] = double.parse(rateController.text) * plot['areaSqYd'];
                    plot['deadlineDate'] = DateTime.now().add(const Duration(days: 90)).toIso8601String();
                    plot['payments'] = [];
                    _updateState();
                    Navigator.pop(ctx);
                  },
                  child: const Text('AUTHORIZE SALE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumInput(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.grey, fontSize: 13), filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  String _fmt(num val) => val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
}

// ---------------------------------------------------------------------------
// SHEET: CARVE NEW PLOT
// ---------------------------------------------------------------------------
class CarvePlotSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const CarvePlotSheet({super.key, required this.onSave});
  @override
  State<CarvePlotSheet> createState() => _CarvePlotSheetState();
}

class _CarvePlotSheetState extends State<CarvePlotSheet> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _rateController = TextEditingController(text: '12000');
  double _calculatedSqYd = 0.0;

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_calculateArea);
    _depthController.addListener(_calculateArea);
  }

  void _calculateArea() {
    final w = double.tryParse(_widthController.text.trim()) ?? 0.0;
    final d = double.tryParse(_depthController.text.trim()) ?? 0.0;
    setState(() => _calculatedSqYd = (w * d) / 9.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            const Text('CARVE NEW PLOT', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            _premiumInput(_nameController, 'Plot Number / Block Name'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _premiumInput(_widthController, 'Width (ft)', isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _premiumInput(_depthController, 'Depth (ft)', isNumber: true)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calculated Area (Gaj):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text('${_calculatedSqYd.toStringAsFixed(2)} Sq. Yd.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _premiumInput(_rateController, 'Base Target Rate (₹/Sq.Yd)', isNumber: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (_nameController.text.isEmpty || _calculatedSqYd <= 0) return;
                  widget.onSave({
                    'plotNo': _nameController.text, 'widthFt': double.parse(_widthController.text),
                    'depthFt': double.parse(_depthController.text), 'areaSqYd': _calculatedSqYd,
                    'status': 'OPEN', 'baseRate': double.parse(_rateController.text), 'payments': []
                  });
                },
                child: const Text('SAVE TO INVENTORY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumInput(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.grey, fontSize: 13), filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. VOUCHERS TAB
// ---------------------------------------------------------------------------
class VouchersTab extends StatelessWidget {
  final double currentFloat;
  final List<Map<String, dynamic>> vouchers;
  final Function(Map<String, dynamic>) onAddVoucher;

  const VouchersTab({super.key, required this.currentFloat, required this.vouchers, required this.onAddVoucher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 100),
          children: [
            const Text('SITE VOUCHERS', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Petty Cash', style: TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LIVE CASH FLOAT', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('₹${currentFloat.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _NewVoucherSheet(currentFloat: currentFloat, onSave: (v) { onAddVoucher(v); Navigator.pop(ctx); })),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('RECORD EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text('RECENT VOUCHERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            ...vouchers.map((v) => Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Color(0xFF0F172A), size: 20)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('Paid to: ${v['payee']}', style: const TextStyle(color: Colors.grey, fontSize: 11))])),
                  Text('- ₹${(v['amount'] as double).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _NewVoucherSheet extends StatefulWidget {
  final double currentFloat;
  final Function(Map<String, dynamic>) onSave;
  const _NewVoucherSheet({required this.currentFloat, required this.onSave});
  @override
  State<_NewVoucherSheet> createState() => _NewVoucherSheetState();
}

class _NewVoucherSheetState extends State<_NewVoucherSheet> {
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  String _selectedCategory = 'Water Tanker';
  double _enteredAmount = 0.0;
  final List<String> _categories = ['Water Tanker', 'Diesel for Machine', 'Hospitality', 'Daily Labor', 'Others'];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() => _enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.currentFloat - _enteredAmount;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            const Text('LOG EXPENSE', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(controller: _amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount Paid (₹)', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _selectedCategory, decoration: InputDecoration(labelText: 'Category', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (val) => setState(() => _selectedCategory = val!)),
            const SizedBox(height: 12),
            TextFormField(controller: _payeeController, decoration: InputDecoration(labelText: 'Paid To (Vendor)', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: remaining < 0 ? Colors.grey : const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: remaining < 0 ? null : () => widget.onSave({'title': _selectedCategory, 'amount': _enteredAmount, 'payee': _payeeController.text, 'mode': 'Cash in Hand', 'date': 'Just Now'}),
                child: const Text('SAVE & DEDUCT CASH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. CONTRACTORS & COMPASS TABS
// ---------------------------------------------------------------------------
class ContractorStatementTab extends StatelessWidget {
  const ContractorStatementTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 100),
          children: [
            const Text('SITE VENDORS', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Contractors', style: TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('NET PAYABLE', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('₹1,17,500', style: TextStyle(color: Color(0xFF34D399), fontSize: 40, fontWeight: FontWeight.w800)), SizedBox(height: 16), Text('Gross Work: ₹1,82,500  |  Advances: -₹65,000', style: TextStyle(color: Colors.white70, fontSize: 12))])),
          ],
        ),
      ),
    );
  }
}

class MarginCompassTab extends StatelessWidget {
  const MarginCompassTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 100),
          children: [
            const Text('FINANCIALS', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Margin Compass', style: TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.deepOrange.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('REQUIRED TARGET RATE', style: TextStyle(color: Colors.deepOrange, fontSize: 11, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('₹13,346 / Sq.Ft.', style: TextStyle(color: Color(0xFF0F172A), fontSize: 32, fontWeight: FontWeight.w800)), Divider(height: 30), Text('Break-Even Floor: ₹10,269 / Sq.Ft.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))])),
          ],
        ),
      ),
    );
  }
}
