import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/decision.dart';
import 'legal_source.dart';

/// محرك قواعد بسيط: كل قاعدة معرَّفة في assets/rules/rules.json
/// وتشير إلى نص قانوني يُجلب من [LegalSource] ليُعرض مرجعًا في التقرير.
class ComplianceEngine {
  final LegalSource legal;
  ComplianceEngine(this.legal);

  Future<ComplianceReport> evaluate(ParsedDecision d) async {
    final rules = jsonDecode(await rootBundle.loadString('assets/rules/rules.json'))
        as List<dynamic>;
    final findings = <Finding>[];

    for (final r in rules.cast<Map<String, dynamic>>()) {
      final passed = _check(r['check'] as String, d, r);
      String? ref;
      final refQuery = r['legal_query'] as String?;
      if (refQuery != null) {
        try {
          final hits = await legal.search(refQuery, limit: 1);
          if (hits.isNotEmpty) {
            ref = '${hits.first.title}${hits.first.articleNo != null ? "، المادة ${hits.first.articleNo}" : ""}';
          }
        } catch (_) {
          // غياب القاعدة السحابية أو الاتصال لا يوقف الفحص.
        }
      }
      findings.add(Finding(
        ruleId: r['id'] as String,
        severity: Severity.values.byName(r['severity'] as String),
        message: passed ? r['pass_message'] as String : r['fail_message'] as String,
        legalReference: ref ?? r['default_reference'] as String?,
        passed: passed,
      ));
    }
    return ComplianceReport(d, findings);
  }

  bool _check(String check, ParsedDecision d, Map<String, dynamic> rule) {
    switch (check) {
      case 'has_number':
        return d.number != null;
      case 'has_date':
        return d.date != null;
      case 'has_issuer':
        return d.issuer != null;
      case 'has_visas':
        return d.visas.length >= (rule['min'] as int? ?? 1);
      case 'has_articles':
        return d.hasArticles;
      case 'has_signature':
        return d.hasSignature;
      case 'has_seal':
        return d.hasSeal;
      case 'visa_mentions':
        final needle = rule['needle'] as String;
        return d.visas.any((v) => v.contains(needle)) ||
            d.rawText.contains(needle);
      default:
        return true;
    }
  }
}
