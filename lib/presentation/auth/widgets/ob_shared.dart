import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

// ── Deporte data ──────────────────────────────────────────────────────────────

class OBDeporte {
  final String key;
  final String label;
  final IconData icon;
  const OBDeporte(this.key, this.label, this.icon);
}

const kDeportes = [
  OBDeporte('futbol', 'Fútbol', Icons.sports_soccer),
  OBDeporte('basquet', 'Básquet', Icons.sports_basketball),
  OBDeporte('voley', 'Vóley', Icons.sports_volleyball),
  OBDeporte('hockey', 'Hockey', Icons.sports_hockey),
  OBDeporte('padel', 'Pádel', Icons.sports_tennis),
  OBDeporte('natacion', 'Natación', Icons.pool),
  OBDeporte('running', 'Running', Icons.directions_run),
  OBDeporte('otro', 'Otro', Icons.emoji_events),
];

IconData deporteIcon(String key) {
  final d = kDeportes.where((d) => d.key == key).firstOrNull;
  return d?.icon ?? Icons.emoji_events;
}

const kGrupoColores = [
  Color(0xFFC85A30),
  Color(0xFF4B6BDB),
  Color(0xFF3A8FA0),
  Color(0xFF2D9B65),
  Color(0xFF7B4DC2),
];

String hexColor(Color c) {
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

// ── OBBtn ─────────────────────────────────────────────────────────────────────

class OBBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool light;
  final bool isLoading;

  const OBBtn(
    this.label, {
    super.key,
    this.onTap,
    this.light = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !isLoading;
    final bg = disabled
        ? AppTheme.border
        : light
            ? Colors.white
            : AppTheme.primary;
    final fg = disabled
        ? AppTheme.textMuted
        : light
            ? AppTheme.primary
            : Colors.white;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: fg,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
      ),
    );
  }
}

// ── OBOutlineBtn ──────────────────────────────────────────────────────────────

class OBOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool onDark;

  const OBOutlineBtn(this.label, {super.key, this.onTap, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final borderColor = onDark
        ? Colors.white.withValues(alpha: 0.3)
        : AppTheme.border;
    final textColor = onDark
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── OBBack ────────────────────────────────────────────────────────────────────

class OBBack extends StatelessWidget {
  final VoidCallback onTap;
  final bool light;

  const OBBack({super.key, required this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.2) : AppTheme.surf(context),
          shape: BoxShape.circle,
          border: light
              ? Border.all(color: Colors.white.withValues(alpha: 0.3))
              : Border.all(color: AppTheme.brd(context)),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: light ? Colors.white : AppTheme.txt(context),
        ),
      ),
    );
  }
}

// ── OBField ───────────────────────────────────────────────────────────────────

class OBField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const OBField({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brd(context)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.txt(context),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

// ── OBBreadcrumb ──────────────────────────────────────────────────────────────
// step: 1=Inicio, 2=Cuenta, 3=Perfil, 4=Grupo
// Shows breadcrumb path + linear progress bar. Used on all intermediate steps.

class OBBreadcrumb extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final Widget? trailing;

  const OBBreadcrumb({
    super.key,
    required this.step,
    this.onBack,
    this.trailing,
  });

  static const _labels = ['Inicio', 'Cuenta', 'Perfil', 'Grupo'];
  static const _total = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            onBack != null
                ? OBBack(onTap: onBack!)
                : const SizedBox(width: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  for (int i = 0; i < _labels.length; i++) ...[
                    Text(
                      _labels[i],
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: i == step - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == step - 1
                            ? AppTheme.primary
                            : i < step - 1
                                ? AppTheme.textMuted
                                : AppTheme.brd(context),
                      ),
                    ),
                    if (i < _labels.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 13,
                          color: i < step - 1
                              ? AppTheme.textMuted
                              : AppTheme.brd(context),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (step - 1) / (_total - 1),
            backgroundColor: AppTheme.brd(context),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 2.5,
          ),
        ),
      ],
    );
  }
}
