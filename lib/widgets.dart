import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'calc.dart';
import 'icons.dart';
import 'logo.dart';
import 'theme.dart';

/// iOS large-title navigation bar that collapses on scroll.
Widget largeTitleBar(
  BuildContext context,
  String title, {
  Widget? leading,
  Widget? trailing,
}) {
  final p = Palette.of(context);
  return CupertinoSliverNavigationBar(
    largeTitle: Text(title),
    automaticallyImplyLeading: false,
    backgroundColor: p.bg.withValues(alpha: 0.92),
    border: null,
    leading: leading,
    trailing: trailing,
  );
}

/// Logo and name for the top-left of a navigation bar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WattlyLogo(size: 28),
        const SizedBox(width: 8),
        Text('Wattly',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: p.label)),
      ],
    );
  }
}

/// Round accent "+" button used in navigation bars.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: 'Log usage',
      child: GestureDetector(
        key: const Key('add-usage'),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          child: PlusIcon(size: 16, color: p.onAccent),
        ),
      ),
    );
  }
}

/// Inset grouped list: rounded card with hairline dividers, optional header
/// and footer captions.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.header, this.footer});

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 0.5, thickness: 0.5, indent: 16, color: p.separator));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(header!.toUpperCase(),
                style: TextStyle(fontSize: 13, color: p.secondary)),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: p.card,
            child: Column(children: rows),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(footer!,
                style: TextStyle(fontSize: 13, color: p.secondary)),
          ),
      ],
    );
  }
}

/// A row inside a [Group]: label on the left, [trailing] on the right.
class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // The value takes its natural width and sits at the right edge; the
        // label gets whatever is left and only truncates if it truly must.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: p.label)),
            ),
            const SizedBox(width: 16),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Right-aligned number field for use as [FormRow.trailing].
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.hint = '0',
    this.onChanged,
    this.enabled = true,
    this.width = 140,
    this.keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final double width;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textAlign: TextAlign.end,
        style: TextStyle(fontSize: 17, color: p.label),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(color: p.secondary.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

/// Coloured rounded square holding an icon.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF1C1C1E)),
    );
  }
}

/// iOS segmented control.
class Segmented<T extends Object> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: p.fill,
        thumbColor: p.card,
        children: {
          for (final e in options.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(e.value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.label)),
            ),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Bar chart of usage buckets; the current bucket is highlighted.
class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.buckets});

  final List<Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final maxKwh = buckets.fold<double>(0, (m, b) => b.kwh > m ? b.kwh : m);
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in buckets)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 28,
                    height: 6 + (maxKwh == 0 ? 0 : b.kwh / maxKwh * 74),
                    decoration: BoxDecoration(
                      color: b.isCurrent ? p.accent : p.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(b.label,
                      style: TextStyle(fontSize: 11, color: p.secondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
