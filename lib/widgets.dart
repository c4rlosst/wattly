import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'calc.dart';
import 'icons.dart';
import 'logo.dart';
import 'theme.dart';

/// Keeps the app phone-sized on wide screens (PCs, tablets): a centered column
/// with the rest of the window left as a plain surround. Applied around the
/// whole navigator, so sheets, pickers and dialogs stay inside the column.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child});

  /// Widest the app gets, about the width of the largest phones.
  static const maxWidth = 430.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > maxWidth;
        return ColoredBox(
          color: p.desk,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                // Hairline edges, only when there is a surround to separate from.
                decoration: BoxDecoration(
                  border: wide
                      ? Border.symmetric(
                          vertical: BorderSide(color: p.separator, width: 0.5))
                      : null,
                ),
                // Inside the column the app is phone-sized, so a landscape PC
                // window still reads as portrait (the iOS large titles only
                // expand in portrait).
                child: MediaQuery(
                  data: media.copyWith(
                    size: Size(
                      math.min(constraints.maxWidth, maxWidth),
                      media.size.height,
                    ),
                    // Very large system text would break the fixed-size rows;
                    // keep it readable without overflowing.
                    textScaler: media.textScaler
                        .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
    // Opaque on purpose: a see-through bar makes the browser blur everything
    // behind it on every frame, which is slow on phones and nearly invisible.
    backgroundColor: p.bg,
    border: null,
    // The three tabs live side by side in one route, so no hero transitions.
    transitionBetweenRoutes: false,
    leading: leading,
    trailing: trailing,
  );
}

/// A tap target that shows the pointer cursor on a PC and reacts to taps
/// anywhere inside its bounds, empty space included.
class Tappable extends StatelessWidget {
  const Tappable({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
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
      child: Tappable(
        key: const Key('add-usage'),
        onTap: onPressed,
        // The circle is 34 px, but the touch target is the standard 44 px, so
        // a thumb doesn't miss it.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: p.accent, shape: BoxShape.circle),
              child: PlusIcon(size: 16, color: p.onAccent),
            ),
          ),
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
///
/// With [onTap] the whole row is tappable (for a text field, pass its
/// focus node's `requestFocus`, so tapping the label focuses the field).
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final row = ConstrainedBox(
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
    return onTap == null ? row : Tappable(onTap: onTap, child: row);
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
    this.focusNode,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final double width;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
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
        thumbColor: p.thumb,
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
