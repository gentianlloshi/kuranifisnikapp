import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareVerse({required String arabic, String? translation, required String reference}) async {
    final buffer = StringBuffer();
    buffer.writeln(arabic);
    if (translation != null && translation.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(translation);
    }
    buffer.writeln();
    buffer.write(reference);
    await Share.share(buffer.toString());
  }

  static Future<void> shareText(String text) async {
    if (text.trim().isEmpty) return;
    await Share.share(text);
  }
}
