// Fix pass 4: Emoji mojibake using Unicode escapes to avoid string-delimiter issues.
// Each emoji's CP1252 mojibake is expressed as \uXXXX sequences.
// Processes LONGEST patterns first to avoid partial matches.

import 'dart:io';

void main() {
  // ð = ð   Ÿ = Ÿ   (common prefix for all 4-byte emojis)
  // 3rd/4th byte values (CP1252 decoded):
  //   0x80 = € (€)  0x85 = … (…)  0x8b = ‹ (‹)
  //   0x8c = Œ (Œ)  0x8e = Ž (Ž)  0x91 = ‘ (')
  //   0x92 = ’ (')  0x99 = ™ (™)  0x9a = š (š)
  //   0x9c = œ (œ)  0x9e = ž (ž)  0x92 = ƒ (ƒ as latin F)
  //   0xa5 = ¥ (¥)  0xb4 = ´ (´)  0xbe = ¾ (¾)
  //   0x93 = “ (")  0x94 = ” (")  0x97 = — (—)
  //   0x8a = Š (Š)

  const replacements = <(String, String)>[
    // ── 4-char mojibake (process first) ──────────────────────────────────
    ('ðŸ™Œ', '\u{1F64C}'),  // ðŸ™Œ → 🙌  U+1F64C  F0 9F 99 8C
    ('ðŸ“‹', '\u{1F4CB}'),  // ðŸ"‹ → 📋  U+1F4CB  F0 9F 93 8B
    ('ðŸ”—', '\u{1F517}'),  // ðŸ"— → 🔗  U+1F517  F0 9F 94 97
    ('ðŸ“…', '\u{1F4C5}'),  // ðŸ"… → 📅  U+1F4C5  F0 9F 93 85
    ('ðŸ‘¥', '\u{1F465}'),  // ðŸ'¥ → 👥  U+1F465  F0 9F 91 A5
    ('ðŸ‘‹', '\u{1F44B}'),  // ðŸ'‹ → 👋  U+1F44B  F0 9F 91 8B
    ('ðŸŽ¾', '\u{1F3BE}'),  // ðŸŽ¾ → 🎾  U+1F3BE  F0 9F 8E BE
    ('ðŸš´', '\u{1F6B4}'),  // ðŸš´ → 🚴  U+1F6B4  F0 9F 9A B4
    ('ðŸ¥¾', '\u{1F97E}'),  // ðŸ¥¾ → 🥾  U+1F97E  F0 9F A5 BE
    // ── 3-char mojibake ──────────────────────────────────────────────────
    ('ðŸ…',       '\u{1F3C5}'),  // ðŸ…  → 🏅  U+1F3C5  F0 9F 8F 85
    ('ðŸƒ',       '\u{1F3C3}'),  // ðŸƒ  → 🏃  U+1F3C3  F0 9F 8F 83
    ('ðŸŠ',       '\u{1F3CA}'),  // ðŸŠ  → 🏊  U+1F3CA  F0 9F 8F 8A
    ('ðŸ“',       '\u{1F3D3}'),  // ðŸ"  → 🏓  U+1F3D3  F0 9F 8F 93
    ('ðŸ€',       '\u{1F3C0}'),  // ðŸ€  → 🏀  U+1F3C0  F0 9F 8F 80
    // ── 2-char mojibake (must be last) ───────────────────────────────────
    ('ðŸ',             '\u{1F3D0}'),  // ðŸ   → 🏐  U+1F3D0  F0 9F 8F 90
  ];

  final dir = Directory('lib');
  var totalFiles = 0;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    var content = entity.readAsStringSync();
    var changed = false;

    for (final (from, to) in replacements) {
      if (content.contains(from)) {
        content = content.replaceAll(from, to);
        changed = true;
      }
    }

    if (changed) {
      entity.writeAsStringSync(content);
      totalFiles++;
      print('Fixed: ${entity.path}');
    }
  }

  print('\nDone. Fixed $totalFiles files.');
}
