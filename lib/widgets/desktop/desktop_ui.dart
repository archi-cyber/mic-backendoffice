import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';

/// Minimum width for embedded desktop layouts inside [DesktopShell].
const double kDesktopEmbeddedBreakpoint = 700;

const double kDesktopContentMaxWidth = 1200;
const double kDesktopFormMaxWidth = 960;
const double kDesktopNarrowMaxWidth = 800;

/// True when the page should render its desktop layout (shell list, stack detail, or overlay).
bool isDesktopEmbedded(
  BuildContext context, {
  bool inShell = false,
  bool hideAppBar = false,
}) {
  if (MediaQuery.sizeOf(context).width < kDesktopEmbeddedBreakpoint) {
    return false;
  }
  return inShell || hideAppBar;
}

/// Animated MIC hero banner for desktop detail/form pages.
class DesktopHeroBanner extends StatelessWidget {
  const DesktopHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.accent = AppColors.primary,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        decoration: BoxDecoration(
          gradient: context.mic.accentBanner(accent),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: context.mic.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.mic.accentIconBackground(accent),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.mic.appBarForeground,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Scrollable desktop page wrapper with fade-in content.
class DesktopPageShell extends StatelessWidget {
  const DesktopPageShell({
    super.key,
    required this.child,
    this.banner,
    this.actions,
    this.isLoading = false,
    this.maxWidth = kDesktopContentMaxWidth,
    this.padding,
  });

  final Widget child;
  final Widget? banner;
  final List<Widget>? actions;
  final bool isLoading;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding:
              padding ?? EdgeInsets.all(AppDimensions.paddingLG),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (banner != null) ...[
                      banner!,
                      SizedBox(height: AppDimensions.spacingLG),
                    ],
                    if (actions != null && actions!.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (var i = 0; i < actions!.length; i++) ...[
                            if (i > 0) SizedBox(width: AppDimensions.spacingSM),
                            actions![i],
                          ],
                        ],
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Bordered section card for desktop forms and detail panels.
class DesktopSectionCard extends StatelessWidget {
  const DesktopSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accent = AppColors.primary,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedHeight = constraints.maxHeight.isFinite;
          return Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: accent),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                SizedBox(height: AppDimensions.spacingMD),
                if (boundedHeight)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  )
                else
                  ...children,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Standard cancel / primary action row for desktop forms.
class DesktopFormActions extends StatelessWidget {
  const DesktopFormActions({
    super.key,
    required this.onCancel,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.check,
    this.isLoading = false,
  });

  final VoidCallback onCancel;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isLoading ? null : onCancel,
          child: Text(context.tr('Cancel')),
        ),
        SizedBox(width: AppDimensions.spacingSM),
        FilledButton.icon(
          onPressed: isLoading ? null : onPrimary,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(primaryIcon, size: 20),
          label: Text(primaryLabel),
        ),
      ],
    );
  }
}

/// Compact stat chip for desktop headers.
class DesktopStatChip extends StatelessWidget {
  const DesktopStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: AppDimensions.spacingSM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.mic.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two-column form layout on wide desktop; single column on narrower widths.
class DesktopFormColumns extends StatelessWidget {
  const DesktopFormColumns({
    super.key,
    required this.sections,
    this.spacing = AppDimensions.spacingMD,
  });

  final List<Widget> sections;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (!wide || sections.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            sections[i],
          ],
        ],
      );
    }
    final half = (sections.length / 2).ceil();
    final left = sections.sublist(0, half);
    final right = sections.sublist(half);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < left.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                left[i],
              ],
            ],
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < right.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                right[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-width desktop list workspace: hero, stats, toolbar, content, pagination.
class DesktopListWorkspace extends StatelessWidget {
  const DesktopListWorkspace({
    super.key,
    required this.banner,
    required this.stats,
    required this.toolbar,
    required this.child,
    this.pagination,
    this.isLoading = false,
    this.maxWidth = kDesktopContentMaxWidth,
    this.headerBelow,
  });

  final Widget banner;
  final List<Widget> stats;
  final Widget toolbar;
  final Widget child;
  final Widget? pagination;
  final bool isLoading;
  final double maxWidth;
  final Widget? headerBelow;

  @override
  Widget build(BuildContext context) {
    final outerPad = AppDimensions.paddingLG;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.all(outerPad),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  banner,
                  SizedBox(height: AppDimensions.spacingLG),
                  if (stats.isNotEmpty) ...[
                    Wrap(
                      spacing: AppDimensions.spacingSM,
                      runSpacing: AppDimensions.spacingSM,
                      children: stats,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                  ],
                  if (headerBelow != null) ...[
                    headerBelow!,
                    SizedBox(height: AppDimensions.spacingMD),
                  ],
                  toolbar,
                  SizedBox(height: AppDimensions.spacingMD),
                  Expanded(child: child),
                  if (pagination != null) ...[
                    SizedBox(height: AppDimensions.spacingSM),
                    pagination!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Standard pagination bar for desktop data tables.
class DesktopPaginationBar extends StatelessWidget {
  const DesktopPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    this.itemLabel,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String? itemLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMD,
          vertical: AppDimensions.spacingSM,
        ),
        child: Row(
          children: [
            if (itemLabel != null)
              Expanded(
                child: Text(
                  itemLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
            Text(
              context.tr('Page ${currentPage + 1} of $totalPages'),
              style: theme.textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevious,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// Data table wrapped in a MIC section card with horizontal scroll.
class DesktopDataTableCard extends StatelessWidget {
  const DesktopDataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.fitToWidth = false,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? emptyMessage;
  final IconData emptyIcon;
  final bool fitToWidth;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return DesktopSectionCard(
        title: context.tr('Results'),
        icon: emptyIcon,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXL),
            child: Center(
              child: Column(
                children: [
                  Icon(emptyIcon, size: 48, color: context.mic.textSecondary),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    emptyMessage ?? context.tr('No results'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    return DesktopSectionCard(
      title: context.tr('Results'),
      icon: Icons.table_rows_outlined,
      trailing: Text(
        '${rows.length}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.mic.textSecondary,
        ),
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final table = DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest,
              ),
              dataRowMinHeight: fitToWidth ? 48 : 52,
              dataRowMaxHeight: fitToWidth ? 56 : 64,
              columnSpacing: fitToWidth ? 8 : 24,
              horizontalMargin: fitToWidth ? 8 : 24,
              columns: columns,
              rows: rows,
            );

            if (fitToWidth) {
              return SizedBox(
                width: constraints.maxWidth,
                child: table,
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: table,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Hoverable desktop table row wrapper for list-style tables.
class DesktopHoverRow extends StatefulWidget {
  const DesktopHoverRow({
    super.key,
    required this.child,
    required this.onTap,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color? highlightColor;

  @override
  State<DesktopHoverRow> createState() => _DesktopHoverRowState();
}

class _DesktopHoverRowState extends State<DesktopHoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.highlightColor ?? AppColors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: _hovered ? color.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: widget.child,
        ),
      ),
    );
  }
}

class DesktopSettingsTile extends StatefulWidget {
  const DesktopSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<DesktopSettingsTile> createState() => _DesktopSettingsTileState();
}

class _DesktopSettingsTileState extends State<DesktopSettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: _hovered ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            side: BorderSide(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.45)
                  : context.mic.border.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingLG),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.color),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.mic.textTertiary,
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
