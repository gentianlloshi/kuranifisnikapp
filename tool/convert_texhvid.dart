import 'dart:io';
import 'dart:convert';
import 'package:kurani_fisnik_app/core/utils/logger.dart';

// Clean converter for texhvid JS data to JSON.
// Usage: dart run tool/convert_texhvid.dart [--force]
Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final dir = Directory('assets/data/texhvid');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.js'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  int converted = 0, skipped = 0, failed = 0;
  for (final file in files) {
    final outPath = file.path.replaceFirst(RegExp(r'\.js$'), '.json');
    if (!force && File(outPath).existsSync()) { skipped++; continue; }
    try {
      var src = await file.readAsString();
      if (src.startsWith('\uFEFF')) src = src.substring(1);
      src = _stripLineCommentsPreserveUrls(src);
      final first = src.indexOf('[');
      final last = src.lastIndexOf(']');
      if (first < 0 || last < first) throw StateError('Array literal not found');
      var lit = src.substring(first, last + 1);
      lit = _quoteKeys(lit);
      lit = _convertSingleQuotedStrings(lit);
      lit = lit.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!); // trailing commas
      lit = lit.replaceAll(r'$1', '');
      lit = lit.replaceAll(RegExp('[\u0000-\u0008]'), '');
  // Remove legacy JS escaping of single quote: turn \' into '
  lit = lit.replaceAll(r"\\'", "'");
  // Now escape any remaining lone backslashes that would break JSON
  // (exclude those already part of known escape like \n, \t, \")
  lit = lit.replaceAllMapped(RegExp(r'\\(?![nrt"\\/bfl])'), (m) => r'\\');
      dynamic data;
      try { data = jsonDecode(lit); } catch (e) { stderr.writeln('JSON decode failed for ${file.path}: $e'); failed++; continue; }
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
  await File(outPath).writeAsString(pretty + '\n');
  Logger.i('Converted: ${file.path}', tag: 'TexhvidConvert');
      converted++;
    } catch (e, st) {
      stderr.writeln('Failure converting ${file.path}: $e');
      stderr.writeln(st);
      failed++;
    }
  }
  Logger.i('Done. Converted=$converted Skipped(existing JSON)=$skipped Failed=$failed', tag: 'TexhvidConvert');
}

String _stripLineCommentsPreserveUrls(String input) {
  final sb = StringBuffer();
  bool inSingle = false, inDouble = false, escape = false, inComment = false;
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    final next = i + 1 < input.length ? input[i + 1] : '';
    if (inComment) { if (ch == '\n') { inComment = false; sb.write(ch); } continue; }
    if (escape) { sb.write(ch); escape = false; continue; }
    if (ch == '\\') { if (inSingle || inDouble) escape = true; sb.write(ch); continue; }
    if (!inSingle && !inDouble && ch == '/' && next == '/') {
      // Check if part of URL (look back for ':')
      int p = sb.length - 1; while (p >= 0 && _isWhitespace(sb.toString()[p])) p--;
      if (p >= 0 && sb.toString()[p] == ':') { sb.write('//'); i++; continue; }
      inComment = true; i++; continue;
    }
    if (ch == "'" && !inDouble) { inSingle = !inSingle; sb.write(ch); continue; }
    if (ch == '"' && !inSingle) { inDouble = !inDouble; sb.write(ch); continue; }
    sb.write(ch);
  }
  return sb.toString();
}

String _quoteKeys(String input) {
  final out = StringBuffer();
  bool inSingle = false, inDouble = false, escape = false;
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    if (escape) { out.write(ch); escape = false; continue; }
    if (ch == '\\') { if (inSingle || inDouble) escape = true; out.write(ch); continue; }
    if (ch == '"' && !inSingle) { inDouble = !inDouble; out.write(ch); continue; }
    if (ch == "'" && !inDouble) { inSingle = !inSingle; out.write(ch); continue; }
    if (!inSingle && !inDouble && _isIdentStart(ch)) {
      int j = i + 1; while (j < input.length && _isIdentPart(input[j])) j++;
      int k = j; while (k < input.length && _isWhitespace(input[k])) k++;
      if (k < input.length && input[k] == ':') {
        // previous non-ws output char
        int p = out.length - 1; while (p >= 0 && _isWhitespace(out.toString()[p])) p--;
        if (p < 0 || '{,'.contains(out.toString()[p])) {
          final key = input.substring(i, j);
          out.write('"$key"');
          i = j - 1; continue;
        }
      }
    }
    out.write(ch);
  }
  return out.toString();
}

String _convertSingleQuotedStrings(String input) {
  final sb = StringBuffer();
  bool inSingle = false, inDouble = false, escape = false;
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    if (escape) { sb.write(ch); escape = false; continue; }
    if (ch == '\\') { if (inSingle || inDouble) escape = true; sb.write(ch); continue; }
    if (inSingle) {
      if (ch == "'") { sb.write('"'); inSingle = false; continue; }
      if (ch == '"') { sb.write('\\"'); continue; }
      sb.write(ch); continue;
    }
    if (inDouble) { if (ch == '"') { inDouble = false; } sb.write(ch); continue; }
    if (ch == "'") { inSingle = true; sb.write('"'); continue; }
    if (ch == '"') { inDouble = true; sb.write(ch); continue; }
    sb.write(ch);
  }
  return sb.toString();
}

bool _isIdentStart(String ch) { final c = ch.codeUnitAt(0); return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || ch == '_'; }
bool _isIdentPart(String ch) { final c = ch.codeUnitAt(0); return _isIdentStart(ch) || (c >= 48 && c <= 57); }
bool _isWhitespace(String ch) => ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';
