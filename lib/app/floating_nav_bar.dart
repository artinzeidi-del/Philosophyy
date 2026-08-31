import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/color_tokens.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/motion.dart';

/// The phone navigation: a dark pill that floats over the content.
///
/// ## Why not `NavigationBar`
///
/// Material's bar is a full-width block welded to the bottom edge, and it ends
/// a screen with a horizontal rule and five labels. That is fine and it is
/// also the reason the product read as an admin tool: the last thing the eye
/// meets is a piece of chrome the same width as everything above it.
///
/// A floating pill inverts the relationship. Content runs under it, the bar is
/// visibly a control rather than a border, and the rounded dark shape gives the
/// page a foot to stand on. The cost is that content must reserve room to
/// scroll clear of it, which is what [reservedHeight] is for.
///
/// ## What the selection does
///
/// The selected destination expands to show its label and the pill behind it
/// slides rather than cutting, so the eye can follow where it went. Both are
/// animated through [Motion.duration], so a reader who has asked for reduced
/// motion gets the same layout with the movement removed rather than a
/// different bar.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<NavBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Space a scrolling screen must leave at its bottom so the last item is not
  /// permanently under the bar.
  ///
  /// The bar itself plus the gap it floats in; callers add their own safe-area
  /// inset on top, since that varies by device.
  static const double reservedHeight = 92;

  /// The icon's own size, and the padding around it in each state.
  static const double _iconSize = 22;

  /// The smallest a destination may be, whatever its icon and padding work
  /// out to.
  ///
  /// An idle destination came to 46×46 — two pixels under the figure both
  /// platform guidelines settle on, and this is the control a reader presses
  /// more than any other in the product. Nothing looked wrong, and the
  /// framework's own accessibility guideline said so the first time it was
  /// asked.
  static const double minimumTapTarget = 48;

  /// Chosen so an idle destination reaches [minimumTapTarget] exactly,
  /// rather than the 46 pixels the spacing token happened to give.
  static const double _idlePadding = (minimumTapTarget - _iconSize) / 2;
  static const double _selectedPadding = Spacing.lg;

  /// Whether the row has room to show [label] on the selected destination.
  ///
  /// The width is measured rather than compared against a threshold. A magic
  /// number would have to be right for both languages, every label, and every
  /// font-scale setting at once — and it was not: 74 per destination dropped
  /// the label on a 390-wide phone that had forty pixels to spare, while a
  /// smaller number would overflow the moment a reader turns text size up.
  static bool _hasRoomForLabel(
    BuildContext context,
    double available,
    String label,
    int destinationCount,
  ) {
    final style = Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    const idle = _iconSize + _idlePadding * 2;
    final selected =
        _iconSize + _selectedPadding * 2 + Spacing.sm + painter.width;
    painter.dispose();

    // One gap of slack, so a row that only just fits does not look wedged.
    // More than that is not free: at 390 logical pixels the row needs 331 of
    // its 342, so a 16-pixel margin dropped the label on a phone with room
    // for it.
    return idle * (destinationCount - 1) + selected + Spacing.sm <= available;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    // Near-black in both themes — see the tokens for why it is not a scheme
    // colour. The light variant is a shade lighter and a shade more opaque,
    // because it has a bright page behind it rather than a dark one.
    final barColor = dark
        ? AppColors.navSurfaceDark.withValues(alpha: 0.90)
        : AppColors.navSurfaceLight.withValues(alpha: 0.94);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.md,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
          child: BackdropFilter(
            // The blur matters: content scrolls underneath, and a flat fill
            // over moving text reads as a hole punched in the page.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
                // The hairline is what turns a dark rectangle into an object
                // with an edge; the shadow underneath is what lifts it off the
                // page.
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.5 : 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: DecoratedBox(
                // A pool of light along the top edge, so the bar reads as a
                // glossy object catching the room rather than as a flat fill.
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Radii.xl),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, 0.55],
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Padding(
                  // Half the horizontal inset the vertical one uses. Raising
                  // each destination to the platform's minimum touch target
                  // added eight pixels across the row, which was enough to
                  // push the selected label out at 390 — a common phone
                  // width. The eight pixels come back from here, where they
                  // cost nothing: the bar is a floating pill and its own
                  // rounding already reads as an inset.
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xs,
                    vertical: Spacing.sm,
                  ),
                  // Five icons plus one label does not fit a 320-wide phone —
                  // "Settings" and «تنظیمات» both overflowed by enough to break
                  // the row. Below the threshold the bar keeps the icons and
                  // drops the label, which is the part a reader can do without:
                  // the selected pill still says where they are.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showLabel = _hasRoomForLabel(
                        context,
                        constraints.maxWidth,
                        destinations[selectedIndex.clamp(
                              0,
                              destinations.length - 1,
                            )]
                            .label,
                        destinations.length,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (var i = 0; i < destinations.length; i++)
                            _NavItem(
                              key: destinations[i].key,
                              destination: destinations[i],
                              selected: i == selectedIndex,
                              showLabel: showLabel,
                              onTap: () => onSelected(i),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination in the floating bar.
class NavBarDestination {
  const NavBarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.key,
  });

  /// Put on the rendered item, so a test can find this destination without
  /// depending on its label or on which control the width selected.
  final Key? key;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    super.key,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final NavBarDestination destination;
  final bool selected;

  /// Whether there is room for the selected destination to name itself.
  final bool showLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Both foregrounds are measured against the near-black bar, not against the
    // page, which is why they do not come from the colour scheme.
    const idle = AppColors.navIdle;
    // The accent, in both themes: the bar is near-black either way, so the
    // light theme's darkened ember would disappear on it. It colours the pill;
    // the label and icon on top of the pill go white, which is what the
    // reference does and what keeps them legible on a lit fill.
    const active = AppColors.ember;
    const onActive = AppGradients.onGradient;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: Tooltip(
        // The bar shows one label at a time, so every other destination is an
        // icon. `Semantics` names them for a screen reader; this names them
        // for everyone else, on hover or long press.
        message: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
            child: AnimatedContainer(
              duration: Motion.duration(context, MotionTokens.quick),
              curve: MotionTokens.standard,
              padding: EdgeInsets.symmetric(
                horizontal: selected && showLabel
                    ? FloatingNavBar._selectedPadding
                    : FloatingNavBar._idlePadding,
                vertical: FloatingNavBar._idlePadding,
              ),
              // The lit pill from the reference navigation, declared once in
              // `Glass.active` so that the desktop rail says "you are here"
              // the same way this does. It used to be written out here only,
              // and the rail had a flat fill.
              decoration: selected
                  ? Glass.active(
                      active,
                      radius: const BorderRadius.all(
                        Radius.circular(Radii.pill),
                      ),
                    )
                  : const BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(Radii.pill),
                      ),
                    ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: FloatingNavBar._iconSize,
                    color: selected ? onActive : idle,
                  ),
                  // The label appears only for the selected destination. Five
                  // labels at once is what forces the icons small enough to stop
                  // being recognisable, and the selected one is the only label a
                  // reader needs — they can see where they are.
                  // The label stays in the tree when it is not shown, because
                  // the width factor is what makes it slide open rather than
                  // appear. `ExcludeSemantics` keeps it out of the accessibility
                  // tree all the same: the item is already named by the
                  // `Semantics` above, and a screen reader that reads all five
                  // labels at every stop is worse than one that reads none.
                  ExcludeSemantics(
                    child: ClipRect(
                      child: AnimatedAlign(
                        duration: Motion.duration(context, MotionTokens.quick),
                        curve: MotionTokens.standard,
                        // Directional: the label opens away from the icon, and
                        // in Persian the icon is on the other side. Anchored
                        // left, the label slid open from the wrong edge.
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: selected && showLabel ? 1 : 0,
                        // `Align` only shrink-wraps an axis it has been given a
                        // factor for. Setting the width factor alone left the
                        // height unconstrained, so this expanded to the tallest
                        // box on offer — and because every ancestor sized to its
                        // child, the bar grew to fill the entire screen.
                        heightFactor: 1,
                        child: AnimatedOpacity(
                          duration: Motion.duration(
                            context,
                            MotionTokens.quick,
                          ),
                          opacity: selected && showLabel ? 1 : 0,
                          child: Padding(
                            // The gap belongs between the label and its icon.
                            // Fixed to the left, it fell on the far side of the
                            // label in Persian and the text touched the icon.
                            padding: const EdgeInsetsDirectional.only(
                              start: Spacing.sm,
                            ),
                            child: Text(
                              destination.label,
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: onActive,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
