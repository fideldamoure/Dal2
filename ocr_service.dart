import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// استخراج النص العربي من صورة القرار عبر Tesseract (يعمل دون إنترنت).
///
/// ملاحظة: Google ML Kit لا يدعم الحرف العربي، لذلك استُخدم Tesseract.
/// يمكن لاحقًا إضافة مزوّد سحابي (Cloud Vision / Document AI) خلف نفس الواجهة.
abstract class OcrService {
  Future<String> recognize(String imagePath);
}

class TesseractOcrService implements OcrService {
  @override
  Future<String> recognize(String imagePath) {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: 'ara',
      args: {'psm': '4', 'preserve_interword_spaces': '1'},
    );
  }
}
