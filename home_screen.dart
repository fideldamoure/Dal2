import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/decision.dart';
import '../services/compliance_engine.dart';
import '../services/decision_parser.dart';
import '../services/legal_source.dart';
import '../services/ocr_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _ocr = TesseractOcrService();
  final _parser = DecisionParser();

  LegalSource? _legal;
  bool _busy = false;
  String? _error;
  ComplianceReport? _report;

  @override
  void initState() {
    super.initState();
    _initLegal();
  }

  /// يستعمل القاعدة السحابية إن ضُبط رابطها ومفتاحها في الإعدادات، وإلا المحلية.
  Future<void> _initLegal() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('cloud_url');
    final key = prefs.getString('cloud_key');
    final src = (url != null && url.isNotEmpty && key != null && key.isNotEmpty)
        ? CloudLegalSource(baseUrl: url, apiKey: key) as LegalSource
        : LocalLegalSource();
    await src.init();
    if (mounted) setState(() => _legal = src);
  }

  Future<void> _scan(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null || _legal == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
    });
    try {
      final text = await _ocr.recognize(file.path);
      final decision = _parser.parse(text);
      final report = await ComplianceEngine(_legal!).evaluate(decision);
      setState(() => _report = report);
    } catch (e) {
      setState(() => _error = 'تعذّر إتمام الفحص: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = TextEditingController(text: prefs.getString('cloud_url') ?? '');
    final key = TextEditingController(text: prefs.getString('cloud_key') ?? '');
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مصدر النصوص القانونية'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اتركهما فارغين لاستعمال القاعدة المحلية على الهاتف.'),
          TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'رابط REST السحابي')),
          TextField(
              controller: key,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'مفتاح الوصول')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (saved == true) {
      await prefs.setString('cloud_url', url.text.trim());
      await prefs.setString('cloud_key', key.text.trim());
      await _initLegal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مطابقة القرارات الإدارية'),
          actions: [
            IconButton(
                icon: const Icon(Icons.settings), onPressed: _openSettings),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _scan(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('تصوير قرار'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('من المعرض'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_report != null) ..._reportWidgets(_report!),
          const SizedBox(height: 24),
          const Text(
            'النتائج ملاحظات أولية للمراجعة، وليست رأيًا قانونيًا نهائيًا.',
            style: TextStyle(color: Colors.grey),
          ),
        ]),
      ),
    );
  }

  List<Widget> _reportWidgets(ComplianceReport r) => [
        Text('عدد الملاحظات غير المستوفاة: ${r.failed}',
            style: Theme.of(context).textTheme.titleMedium),
        for (final f in r.findings)
          Card(
            child: ListTile(
              leading: Icon(
                f.passed
                    ? Icons.check_circle
                    : (f.severity == Severity.error
                        ? Icons.error
                        : Icons.warning_amber),
                color: f.passed
                    ? Colors.green
                    : (f.severity == Severity.error ? Colors.red : Colors.orange),
              ),
              title: Text(f.message),
              subtitle: f.legalReference == null ? null : Text(f.legalReference!),
            ),
          ),
        ExpansionTile(
          title: const Text('النص المستخرج (للتحقق من جودة OCR)'),
          children: [SelectableText(r.decision.rawText)],
        ),
      ];
}
