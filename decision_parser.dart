import '../models/decision.dart';

/// يحوّل الأرقام العربية-الهندية إلى لاتينية لتسهيل المطابقة.
String normalizeDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// يستخرج عناصر القرار من نص OCR. الأنماط أولية وتحتاج ضبطًا على عيّنات حقيقية.
class DecisionParser {
  ParsedDecision parse(String raw) {
    final text = normalizeDigits(raw);

    final number = RegExp(r'قرار\s*رقم\s*[:：]?\s*([\d٠-٩/\-\.]+)')
        .firstMatch(text)
        ?.group(1);

    final date = RegExp(r'(\d{1,2}\s*[/\-\.]\s*\d{1,2}\s*[/\-\.]\s*\d{4})')
        .firstMatch(text)
        ?.group(1);

    final issuer = RegExp(r'(رئيس\s+المجلس\s+الشعبي\s+البلدي[^\n]*|الوالي[^\n]*|المدير[^\n]*)')
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    // التأشيرات: الأسطر التي تبدأ بـ "بمقتضى" أو "بناء على" أو "وبمقتضى".
    final visas = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => RegExp(r'^(و?بمقتضى|و?بناء\s+على|و?بموجب)').hasMatch(l))
        .toList();

    final hasArticles = RegExp(r'المادة\s+(الأولى|1|الاولى)').hasMatch(text);
    final hasSignature = RegExp(r'(الإمضاء|الامضاء|توقيع)').hasMatch(text);
    final hasSeal = RegExp(r'(الختم|ختم)').hasMatch(text);

    return ParsedDecision(
      rawText: raw,
      number: number,
      date: date,
      issuer: issuer,
      visas: visas,
      hasArticles: hasArticles,
      hasSignature: hasSignature,
      hasSeal: hasSeal,
    );
  }
}
