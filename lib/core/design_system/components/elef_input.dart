import 'package:flutter/material.dart';
import '../tokens/elef_colors.dart';
import '../tokens/elef_radius.dart';
import '../tokens/elef_spacing.dart';
import '../tokens/elef_typography.dart';

/// ELEF Design System — Champ de Saisie Professionnel
class ElefInput extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const ElefInput({
    super.key,
    this.label,
    this.hintText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: ElefTypography.caption.copyWith(
              color: ElefColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ElefSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: ElefTypography.bodyMedium.copyWith(color: ElefColors.textDisabled),
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: ElefColors.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: ElefRadius.md,
              borderSide: const BorderSide(color: ElefColors.borderMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: ElefRadius.md,
              borderSide: const BorderSide(color: ElefColors.borderMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: ElefRadius.md,
              borderSide: const BorderSide(color: ElefColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Champ de recherche épuré avec icône loupe intégrée
class ElefSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const ElefSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Rechercher un cours, une leçon, un bloc...',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: ElefTypography.bodyMedium.copyWith(color: ElefColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: ElefTypography.bodySmall.copyWith(color: ElefColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: ElefColors.textMuted, size: 20),
        suffixIcon: controller?.text.isNotEmpty == true
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: ElefColors.textMuted),
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
              )
            : null,
        filled: true,
        fillColor: ElefColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: ElefRadius.md,
          borderSide: const BorderSide(color: ElefColors.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ElefRadius.md,
          borderSide: const BorderSide(color: ElefColors.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ElefRadius.md,
          borderSide: const BorderSide(color: ElefColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
