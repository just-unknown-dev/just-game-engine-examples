import 'package:flutter/material.dart';

/// A widget that shows a responsive layout based on screen width.
///
/// On wide screens (desktop/tablet), it shows a split view with the [menuList]
/// on the left and the [showcaseArea] on the right.
/// On narrow screens (mobile), it only shows the [menuList], and relies on
/// the parent to push navigation.
class ResponsiveLayout extends StatelessWidget {
  final Widget menuList;
  final Widget showcaseArea;
  final bool isMobile;

  const ResponsiveLayout({
    super.key,
    required this.menuList,
    required this.showcaseArea,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return menuList;
    }

    return Row(
      children: [
        // Menu List (fixed width)
        SizedBox(width: 300, child: menuList),
        // Vertical Divider
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF2a2a3e)),
        // Showcase Area (takes remaining space)
        Expanded(child: showcaseArea),
      ],
    );
  }
}
