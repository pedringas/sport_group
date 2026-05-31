// Fix pass 3: Symbols corrupted by CP1252 mojibake
// â + ˆ(U+02C6) + '(U+2019)  →  − (U+2212 minus sign)
// â + œ(U+0153) + "(U+201C)  →  ✓ (U+2713 check mark)
// â + †(U+2020) + '(U+2019)  →  → (U+2192 right arrow)
// "(U+201C) + ¦(U+00A6)      →  … (U+2026 ellipsis)

import 'dart:io';

void main() {
  const replacements = [
    // longest first to avoid partial matches
    ('âˆ’', '−'),   // âˆ' → − (minus sign)
    ('âœ“', '✓'),   // âœ" → ✓ (check mark)
    ('â†’', '→'),   // â†' → → (right arrow)
    ('“¦', '…'),    // "¦ → … (ellipsis)
  ];

  final dirs = [
    'lib',
  ];

  int totalFiles = 0;
  int totalReplacements = 0;

  for (final dir in dirs) {
    final entities = Directory(dir).listSync(recursive: true);
    for (final entity in entities) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      var content = entity.readAsStringSync();
      var changed = false;
      var count = 0;

      for (final (from, to) in replacements) {
        final newContent = content.replaceAll(from, to);
        if (newContent != content) {
          count += (content.length - newContent.length) ~/ (from.length - to.length).abs().clamp(1, 999);
          content = newContent;
          changed = true;
        }
      }

      if (changed) {
        entity.writeAsStringSync(content);
        totalFiles++;
        totalReplacements += count;
        print('Fixed: ${entity.path}');
      }
    }
  }

  print('\nDone. Fixed $totalFiles files, ~$totalReplacements replacements.');
}
