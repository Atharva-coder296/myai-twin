import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models.dart';
import '../scanner_logic.dart';
import '../store.dart';

class AuditEntryScreen extends StatefulWidget {
  final RetailStore store;
  const AuditEntryScreen({super.key, required this.store});
  @override
  State<AuditEntryScreen> createState() => _AuditEntryScreenState();
}

class _AuditEntryScreenState extends State<AuditEntryScreen> {
  final brand = TextEditingController();
  final storeCode = TextEditingController();
  final eanLength = TextEditingController(text: '13');
  final auditor = TextEditingController();
  final rack = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    brand.dispose(); storeCode.dispose(); eanLength.dispose();
    auditor.dispose(); rack.dispose(); super.dispose();
  }

  Future<void> start() async {
    if (busy) return;
    if ([brand.text, storeCode.text, auditor.text, rack.text]
        .any((s) => s.trim().isEmpty)) {
      showFailure(context, 'Fill Company, Store, Auditor and Rack fields'); return;
    }
    final expected = int.tryParse(eanLength.text);
    if (expected == null || expected < 1 || expected > 128) {
      showFailure(context, 'EAN length must be between 1 and 128'); return;
    }
    setState(() => busy = true);
    try {
      await widget.store.startAudit(brand: brand.text, storeCode: storeCode.text,
          barcodeLength: expected, auditor: auditor.text, rack: rack.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ActiveAuditScreen(store: widget.store)));
    } catch (e) { showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.draft != null) {
      final audit = widget.store.draft!;
      return Scaffold(appBar: AppBar(title: const Text('Start Scanning')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Unfinished audit found', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${audit.brand} • ${audit.storeCode} • ${audit.racks.length} rack(s)'),
              const SizedBox(height: 12),
              actionButton('Resume Unfinished Audit', () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => ActiveAuditScreen(store: widget.store)))),
            ]))),
        ]));
    }
    return Scaffold(appBar: AppBar(title: const Text('New Audit Details')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Enter these details once. New locations will reuse the brand, store and barcode length.'),
        const SizedBox(height: 15),
        TextField(controller: brand, decoration: const InputDecoration(labelText: 'Company / Brand Name')),
        const SizedBox(height: 12),
        TextField(controller: storeCode, decoration: const InputDecoration(labelText: 'Store Code')),
        const SizedBox(height: 12),
        TextField(controller: eanLength, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Expected EAN / Barcode Length')),
        const SizedBox(height: 12),
        TextField(controller: auditor, decoration: const InputDecoration(labelText: "Auditor's Name")),
        const SizedBox(height: 12),
        TextField(enabled: false, decoration: InputDecoration(labelText: 'Date (automatic)',
          hintText: today())),
        const SizedBox(height: 12),
        TextField(controller: rack, decoration: const InputDecoration(labelText: 'First Rack Location',
          helperText: 'Scan rack QR/barcode here with your 2D scanner or type it')),
        const SizedBox(height: 20),
        actionButton(busy ? 'Starting…' : 'Start Audit', busy ? () {} : start,
          icon: Icons.qr_code_scanner),
      ]));
  }
}

class ActiveAuditScreen extends StatefulWidget {
  final RetailStore store;
  final Audit? existingReport;
  final int initialRack;
  const ActiveAuditScreen({super.key, required this.store,
    this.existingReport, this.initialRack = 0});
  @override
  State<ActiveAuditScreen> createState() => _ActiveAuditScreenState();
}

class _ActiveAuditScreenState extends State<ActiveAuditScreen> {
  final scanInput = TextEditingController();
  final scanFocus = FocusNode();
  Timer? idleTimer;
  bool resolving = false;
  bool dialogOpen = false;
  late int rackIndex;
  int acceptedScans = 0;
  String status = 'Scanner ready';
  String? lastSavedBarcode;

  Audit get audit => widget.existingReport ?? widget.store.draft!;
  RackCount get rack => audit.racks[rackIndex];
  bool get editingExisting => widget.existingReport != null;

  @override
  void initState() {
    super.initState();
    rackIndex = widget.existingReport == null
        ? widget.store.activeDraftRackIndex.clamp(0, audit.racks.length - 1).toInt()
        : widget.initialRack.clamp(0, audit.racks.length - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refocus());
  }

  void _refocus() {
    if (mounted && !resolving && !dialogOpen && scanFocus.canRequestFocus) scanFocus.requestFocus();
  }

  @override
  void dispose() {
    idleTimer?.cancel(); scanInput.dispose(); scanFocus.dispose(); super.dispose();
  }

  void _onInputChanged(String value) {
    if (resolving || dialogOpen) return;
    idleTimer?.cancel();
    if (value.contains('\n') || value.contains('\r')) {
      _commit(value);
    } else if (value.trim().isNotEmpty) {
      // Many keyboard-wedge scanners don't transmit Enter; finish after silence.
      idleTimer = Timer(const Duration(milliseconds: 650), () => _commit(scanInput.text));
    }
  }

  void _commit(String received) {
    if (resolving || dialogOpen || !mounted) return;
    idleTimer?.cancel();
    scanInput.clear(); // Important: never leave scans accumulating in the input field.
    final chunks = received.split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (chunks.isEmpty) { _refocus(); return; }
    // Handle separate line-terminated scans without merging independent rack rows.
    _processQueued(chunks);
  }

  Future<void> _processQueued(List<String> chunks) async {
    if (resolving) return;
    setState(() => resolving = true);
    try {
      for (final code in chunks) {
        if (!mounted) return;
        final check = ScanCheck(code, audit.eanLength);
        if (!check.isNumeric) {
          setState(() => status = 'Rejected: QR/barcode must contain a numeric product ID');
          continue;
        }
        if (check.needsDecision) {
          // Decision appears immediately; sound happens while it is visible.
          final decision = await _askMismatch(code);
          if (!mounted) return;
          if (decision == 'reject') {
            setState(() => status = 'Rejected $code');
            continue;
          }
          if (decision == 'modify') {
            final len = await _askNewLength();
            if (!mounted) return;
            if (len != null) {
              final outcome = resolveMismatch(check, EanDecision.modifyExpectedLength, modifiedLength: len);
              audit.eanLength = outcome.expectedLength;
              await widget.store.save();
              if (!mounted) return;
              setState(() => status = 'Expected barcode length changed to $len. Current scan rejected.');
            }
            continue;
          }
          // Yes: accept only this product; do not modify default length.
          if (!resolveMismatch(check, EanDecision.acceptOnce).accepted) continue;
        }
        if (editingExisting) {
          rack.scan(code);
          await widget.store.save();
        } else {
          await widget.store.scan(rackIndex: rackIndex, barcode: code);
        }
        if (!mounted) return;
        acceptedScans++;
        setState(() {
          lastSavedBarcode = code;
          status = 'Saved $code · ${rack.units} units in this rack';
        });
        if (widget.store.successSound) SystemSound.play(SystemSoundType.click);
        if (widget.store.vibration) HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) {
        setState(() => resolving = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _refocus());
      }
    }
  }

  Future<String> _askMismatch(String code) async {
    if (widget.store.mismatchSound) _tripleAlert();
    if (widget.store.vibration) HapticFeedback.heavyImpact();
    final choice = await showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (dialogContext) => PopScope(canPop: false, child: AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded,
          color: Colors.deepOrange), SizedBox(width: 8), Expanded(child: Text('EAN Length Mismatch'))]),
        content: Text('Scanned: $code\nExpected: ${audit.eanLength} digits\nReceived: ${code.length} digits\n\nAdd this product to the audit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'reject'),
            child: const Text('No — Reject')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'modify'),
            child: const Text('Modify EAN Length')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'accept'),
            child: const Text('Yes — This Product Only')),
        ],
      )),
    );
    return choice ?? 'reject';
  }

  Future<void> _tripleAlert() async {
    for (var i = 0; i < 3; i++) {
      if (!mounted) return;
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 160));
    }
  }

  Future<int?> _askNewLength() async {
    final c = TextEditingController(text: '${audit.eanLength}');
    final result = await showDialog<int>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expected EAN for Upcoming Scans'),
        content: TextField(controller: c, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New length (1–128)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final n = int.tryParse(c.text);
            if (n == null || n < 1 || n > 128) return;
            Navigator.pop(dialogContext, n);
          }, child: const Text('Save New Length')),
        ],
      ));
    c.dispose();
    return result;
  }

  Future<void> _typeBarcodeManually() async {
  if (resolving || dialogOpen) return;

  idleTimer?.cancel();
  scanInput.clear();
  scanFocus.unfocus();
  dialogOpen = true;

  String barcode = '';

  try {
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Numeric barcode',
            hintText: 'Type or paste barcode',
          ),
          onChanged: (value) {
            barcode = value.trim();
          },
          onFieldSubmitted: (value) {
            Navigator.of(dialogContext).pop(value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(barcode);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (code != null && code.isNotEmpty) {
      dialogOpen = false;
      await _processQueued([code]);
    }
  } catch (e) {
    if (mounted) showFailure(context, e);
  } finally {
    dialogOpen = false;

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refocus();
      });
    }
  }
}

Future<void> _addLocation() async {
  if (resolving || dialogOpen) return;

  idleTimer?.cancel();
  scanInput.clear();
  scanFocus.unfocus();
  dialogOpen = true;

  final formKey = GlobalKey<FormState>();
  String locationName = '';
  String auditorName = rack.auditor;

  try {
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Rack Location'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Scan or type rack location',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a location name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    locationName = value!.trim();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: auditorName,
                  decoration: const InputDecoration(
                    labelText: 'Auditor (keep or change)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an auditor name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    auditorName = value!.trim();
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              formKey.currentState!.save();

              Navigator.of(dialogContext).pop(
                (locationName, auditorName),
              );
            },
            child: const Text('Add Location'),
          ),
        ],
      ),
    );

    if (!mounted || values == null) return;

    if (editingExisting) {
      audit.racks.add(
        RackCount(
          id: newId(),
          rack: values.$1,
          auditor: values.$2,
          date: today(),
        ),
      );

      await widget.store.save();
    } else {
      await widget.store.addRack(
        values.$1,
        values.$2,
      );
      widget.store.setActiveDraftRack(audit.racks.length - 1);
    }

    if (!mounted) return;

    setState(() {
      rackIndex = audit.racks.length - 1;
      lastSavedBarcode = null;
      status = 'Location added: ${values.$1}';
    });
  } catch (e) {
    if (mounted) {
      showFailure(context, e);
    }
  } finally {
    dialogOpen = false;

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refocus();
      });
    }
  }
}
  Future<void> _editRow(int index) async {
    final original = rack.rows[index];
    final c = TextEditingController(text: original.barcode);
    final qty = TextEditingController(text: '${original.quantity}');
    final values = await showDialog<(String, int)>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Scanned Product'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Barcode')),
          const SizedBox(height: 12),
          TextField(controller: qty, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final n = int.tryParse(qty.text);
            if (!validBarcode(c.text) || n == null || n < 0) return;
            Navigator.pop(dialogContext, (c.text, n));
          }, child: const Text('Save'))],
      ));
    c.dispose(); qty.dispose();
    if (values != null) {
      // Correct the row's quantity before barcode merging.
      rack.rows[index].quantity = values.$2;
      rack.editBarcode(index, values.$1);
      await widget.store.save();
      if (mounted) setState(() {});
    }
    _refocus();
  }

  Future<void> _end() async {
    if (editingExisting) {
      await widget.store.save();
      if (!mounted) return;
      showSuccess(context, 'Edited audit saved on this device.');
      Navigator.pop(context);
      return;
    }
    if (widget.store.confirmEnd && !await confirmAction(context,
      'End Audit?', 'Save this audit to Audit Reports?', confirmText: 'Continue')) return;
    if (!mounted) return;
    final name = TextEditingController();
    final reportName = await showDialog<String>(context: context,
      builder: (dialogContext) => AlertDialog(title: const Text('Save Audit As'),
        content: TextField(controller: name,
          decoration: const InputDecoration(labelText: 'Audit report name')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, name.text.trim());
          }, child: const Text('Save Audit'))]));
    name.dispose();
    if (reportName == null || !mounted) { _refocus(); return; }
    await widget.store.completeAudit(reportName);
    if (!mounted) return;
    showSuccess(context, 'Audit saved. Automatic email is not connected yet.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.existingReport == null && widget.store.draft == null) {
      return Scaffold(appBar: AppBar(title: const Text('Audit')),
        body: emptyView('No active audit'));
    }
    return Scaffold(
      appBar: AppBar(title: Text(editingExisting ? 'Edit Saved Audit' : 'Active Audit')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${audit.brand} · ${audit.storeCode}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text('Expected barcode length: ${audit.eanLength} · ${audit.date}'),
            const SizedBox(height: 8),
            DropdownButton<int>(value: rackIndex, isExpanded: true,
              items: [for (var i = 0; i < audit.racks.length; i++)
                DropdownMenuItem(value: i, child: Text(audit.racks[i].rack))],
              onChanged: resolving ? null : (i) {
                if (i == null) return;
                idleTimer?.cancel(); scanInput.clear();
                setState(() { rackIndex = i; lastSavedBarcode = null; });
                if (!editingExisting) widget.store.setActiveDraftRack(i);
                _refocus();
              }),
            Text('Auditor: ${rack.auditor} · ${rack.date}'),
          ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BARCODE / NUMERIC QR SCANNER',
              style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Tap the field once. Your 2D USB/Bluetooth scanner should '
              'send Enter after each scan. QR codes containing numeric product IDs work too.',
              style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: scanInput, focusNode: scanFocus, enabled: !resolving,
              autofocus: true, keyboardType: TextInputType.none,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.qr_code_scanner),
                labelText: resolving ? 'Waiting for EAN decision…' : 'Scanner Ready — Scan Here',
                border: const OutlineInputBorder()),
              onChanged: _onInputChanged,
              onSubmitted: _commit),
            const SizedBox(height: 9),
            Text(status, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            TextButton.icon(
              onPressed: resolving ? null : _typeBarcodeManually,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Type a barcode manually'),
            ), 
            if (resolving) const LinearProgressIndicator(),
          ]))),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: resolving ? null : _addLocation,
            icon: const Icon(Icons.add), label: const Text('Add Location'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: resolving ? null : _end,
            icon: const Icon(Icons.save), label: Text(editingExisting ? 'Save Changes' : 'End Audit'))),
        ]),
        const SizedBox(height: 12),
        if (lastSavedBarcode != null) Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text('Last saved: $lastSavedBarcode'),
            subtitle: Text('Location: ${rack.rack}'),
            trailing: Text('Qty: ${rack.rows.where((r) => r.barcode == lastSavedBarcode).fold<int>(0, (sum, r) => sum + r.quantity)}'),
          ),
        ),
        Text('Location Inventory Sheet — ${rack.rack}', style: Theme.of(context).textTheme.titleLarge),
        Text('${rack.rows.length} unique products · ${rack.units} units · $acceptedScans new scans'),
        const SizedBox(height: 7),
        if (rack.rows.isEmpty) emptyView('Scanned products will appear here.'),
        ...List.generate(rack.rows.length, (index) {
          final row = rack.rows[index];
          return Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined),
            title: Text(row.barcode), subtitle: const Text('Tap to edit barcode or quantity'),
            trailing: Text('× ${row.quantity}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            onTap: resolving ? null : () => _editRow(index)));
        }),
      ]),
    );
  }
}
