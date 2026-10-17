import 'package:baladiya_check/services/decision_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('يستخرج الرقم والتاريخ والتأشيرات', () {
    const sample = '''
الجمهورية الجزائرية الديمقراطية الشعبية
قرار رقم: ١٢٣ / 2026
رئيس المجلس الشعبي البلدي
بمقتضى الأمر رقم 06-03 المؤرخ في 15 يوليو 2006
بناء على محضر اللجنة المتساوية الأعضاء
يقرر
المادة الأولى: يُرسَّم السيد ...
حرر ببلدية ... في 05/10/2026
الإمضاء
''';
    final d = DecisionParser().parse(sample);
    expect(d.number, isNotNull);
    expect(d.date, '05/10/2026');
    expect(d.visas.length, 2);
    expect(d.hasArticles, isTrue);
    expect(d.hasSignature, isTrue);
  });
}
