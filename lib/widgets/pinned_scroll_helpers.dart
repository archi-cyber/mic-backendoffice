import 'package:flutter/material.dart';

import '../core/constants/app_dimensions.dart';
import '../core/theme/mic_theme.dart';

/// Fixed-height sliver header that stays pinned while the nested body scrolls.
class SliverPinnedBoxDelegate extends SliverPersistentHeaderDelegate {
  SliverPinnedBoxDelegate({
    required this.height,
    required this.child,
    this.backgroundColor,
  });

  final double height;
  final Widget child;
  final Color? backgroundColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: backgroundColor ?? context.mic.background,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPinnedBoxDelegate oldDelegate) {
    return height != oldDelegate.height ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// Tab body scroll view coordinated with [NestedScrollView] header slivers.
CustomScrollView nestedTabBodyScrollView({
  required BuildContext context,
  required List<Widget> children,
  EdgeInsetsGeometry? padding,
}) {
  return CustomScrollView(
    slivers: [
      SliverOverlapInjector(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
      SliverPadding(
        padding: padding ??
            EdgeInsets.only(
              left: AppDimensions.paddingMD,
              right: AppDimensions.paddingMD,
              top: AppDimensions.spacingMD,
              bottom: AppDimensions.paddingXL,
            ),
        sliver: SliverList(
          delegate: SliverChildListDelegate(children),
        ),
      ),
    ],
  );
}
