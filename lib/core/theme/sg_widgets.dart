import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Shared SportGroups widgets that match the new "Atardecer" design system.
/// Drop these in anywhere you need pill buttons, chips with tones, role chips,
/// section eyebrows, and the warm icon-tile primitives.

// ─────────────────────────────────────────────────────────────────────────────
// SGPillButton — primary pill action (replaces FilledButton when you need a chip
// look, or just want to swap tones).
class SGPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final SGTone tone;
  final SGSize size;
  final bool expand;

  const SGPillButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.tone = SGTone.primary,
    this.size = SGSize.md,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _toneConfig(tone);
    final sizing = _sizeConfig(size);

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: sizing.fs + 4, color: cfg.fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: cfg.fg, fontWeight: FontWeight.w600,
            fontSize: sizing.fs, letterSpacing: 0.1,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: sizing.fs + 4, color: cfg.fg),
        ],
      ],
    );

    return Material(
      color: cfg.bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: sizing.h,
          padding: EdgeInsets.symmetric(horizontal: sizing.padX),
          decoration: cfg.border != null
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: cfg.border,
                )
              : null,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  static ({Color bg, Color fg, BoxBorder? border}) _toneConfig(SGTone t) {
    switch (t) {
      case SGTone.primary:
        return (bg: AppTheme.primary, fg: Colors.white, border: null);
      case SGTone.soft:
        return (bg: AppTheme.primarySoft, fg: AppTheme.primaryInk, border: null);
      case SGTone.accent:
        return (bg: AppTheme.accent, fg: Colors.white, border: null);
      case SGTone.ghost:
        return (bg: Colors.transparent, fg: AppTheme.text, border: null);
      case SGTone.outline:
        return (
          bg: AppTheme.surface,
          fg: AppTheme.text,
          border: Border.all(color: AppTheme.border)
        );
      case SGTone.danger:
        return (bg: AppTheme.danger, fg: Colors.white, border: null);
    }
  }

  static ({double h, double fs, double padX}) _sizeConfig(SGSize s) {
    switch (s) {
      case SGSize.sm: return (h: 36, fs: 13, padX: 14);
      case SGSize.md: return (h: 48, fs: 15, padX: 20);
      case SGSize.lg: return (h: 56, fs: 16, padX: 24);
    }
  }
}

enum SGTone { primary, soft, accent, ghost, outline, danger }
enum SGSize { sm, md, lg }

// ─────────────────────────────────────────────────────────────────────────────
// SGChip — small label chip with tone tinting (neutral/primary/accent/good/danger).
class SGChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SGChipTone tone;
  final bool filled;

  const SGChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = SGChipTone.neutral,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = _toneConfig(tone);
    final bg = filled ? t.fg : t.bg;
    final fg = filled ? Colors.white : t.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: GoogleFonts.dmSans(
            color: fg, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.1,
          )),
        ],
      ),
    );
  }

  static ({Color bg, Color fg}) _toneConfig(SGChipTone t) {
    switch (t) {
      case SGChipTone.neutral: return (bg: AppTheme.surfaceAlt, fg: AppTheme.text);
      case SGChipTone.primary: return (bg: AppTheme.primarySoft, fg: AppTheme.primaryInk);
      case SGChipTone.accent:  return (bg: AppTheme.accentSoft, fg: AppTheme.accentInk);
      case SGChipTone.good:    return (bg: AppTheme.goodSoft,   fg: AppTheme.goodInk);
      case SGChipTone.danger:  return (bg: AppTheme.dangerSoft, fg: AppTheme.dangerInk);
    }
  }
}

enum SGChipTone { neutral, primary, accent, good, danger }

// ─────────────────────────────────────────────────────────────────────────────
// SGEyebrow — uppercase section label
class SGEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;
  const SGEyebrow(this.text, {super.key, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color ?? AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppTheme.border)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SGIconTile — square tinted tile with rounded corners and an icon.
class SGIconTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final double size;
  final double radius;
  final bool filled;

  const SGIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.size = 40,
    this.radius = 12,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: iconColor),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SGAvatar — circular initial avatar with tone background.
class SGAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? background;
  final Color? foreground;

  const SGAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: background ?? AppTheme.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.bricolageGrotesque(
          color: foreground ?? Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size, height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      );
    }
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SGCard — surface card with the standard SG radius, border and padding.
class SGCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;

  const SGCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(20);
    final decoration = BoxDecoration(
      color: color ?? AppTheme.surface,
      borderRadius: shape,
      border: border ?? Border.all(color: AppTheme.border),
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SGErrorState — consistent error + retry widget for async pages
class SGErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const SGErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SGPillButton(
                icon: Icons.refresh_rounded,
                label: 'Reintentar',
                tone: SGTone.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
