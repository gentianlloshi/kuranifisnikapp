/// Lightweight sanitizer to strip simple HTML-like tags from asset strings
/// and decode a few common HTML entities. Keeps inner text intact.
///
/// Notes:
/// - Replaces <br> and <br/> with newlines when preserveLineBreaks=true.
/// - Removes all remaining tags like <span ...> and </span>.
/// - Decodes a small set of common entities used in our data.
String sanitizeHtmlLike(String? input, {bool preserveLineBreaks = true}) {
  if (input == null || input.isEmpty) return '';
  var text = input;

  // Normalize line breaks for <br> variants first if requested
  if (preserveLineBreaks) {
    text = text.replaceAll(RegExp(r"<br\s*/?>", caseSensitive: false), "\n");
  }

  // Remove all remaining HTML tags while preserving inner text
  text = text.replaceAll(RegExp(r"<[^>]+>"), "");

  // Decode a few common HTML entities
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  // Collapse excessive whitespace but keep newlines
  text = text.replaceAll(RegExp(r"[ \t\f\r]+"), ' ');
  // Trim spaces around newlines
  text = text.replaceAll(RegExp(r" *\n *"), '\n');

  return text.trim();
}
