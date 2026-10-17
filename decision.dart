/// القرار الإداري بعد استخراج عناصره من النص.
class ParsedDecision {
  final String rawText;
  final String? number;
  final String? date;
  final String? issuer;
  final List<String> visas; // التأشيرات (بمقتضى ...)
  final bool hasArticles; // وجود مواد في المنطوق
  final bool hasSignature;
  final bool hasSeal;

  const ParsedDecision({
    required this.rawText,
    this.number,
    this.date,
    this.issuer,
    this.visas = const [],
    this.hasArticles = false,
    this.hasSignature = false,
    this.hasSeal = false,
  });
}

enum Severity { info, warning, error }

/// ملاحظة واحدة ناتجة عن فحص قاعدة.
class Finding {
  final String ruleId;
  final Severity severity;
  final String message;
  final String? legalReference; // مثال: "الأمر 06-03، المادة ..."
  final bool passed;

  const Finding({
    required this.ruleId,
    required this.severity,
    required this.message,
    this.legalReference,
    required this.passed,
  });
}

class ComplianceReport {
  final ParsedDecision decision;
  final List<Finding> findings;

  const ComplianceReport(this.decision, this.findings);

  int get failed => findings.where((f) => !f.passed).length;
}

/// نص قانوني مخزَّن في القاعدة.
class LegalText {
  final String id;
  final String title; // مثال: الأمر رقم 06-03
  final String reference; // تاريخ الصدور / الجريدة الرسمية
  final String? articleNo;
  final String body;

  const LegalText({
    required this.id,
    required this.title,
    required this.reference,
    this.articleNo,
    required this.body,
  });

  factory LegalText.fromJson(Map<String, dynamic> j) => LegalText(
        id: j['id'] as String,
        title: j['title'] as String,
        reference: (j['reference'] ?? '') as String,
        articleNo: j['article_no'] as String?,
        body: (j['body'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'reference': reference,
        'article_no': articleNo,
        'body': body,
      };
}
