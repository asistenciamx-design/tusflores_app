import 'package:flutter/material.dart';

/// Breakpoints globales de la app.
/// mobile  : < 768 px
/// tablet  : 768 – 1199 px
/// desktop : ≥ 1200 px
class Breakpoints {
  static const double tablet = 768;
  static const double desktop = 1200;
}

/// Devuelve el ancho actual de la ventana.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isMobile => screenWidth < Breakpoints.tablet;
  bool get isTablet =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// true si es tablet O desktop (útil para mostrar sidebar).
  bool get isWide => screenWidth >= Breakpoints.tablet;
}

/// Widget declarativo para layouts responsive.
///
/// Uso:
/// ```dart
/// ResponsiveLayout(
///   mobile:  _MobileBody(),
///   tablet:  _TabletBody(),   // opcional — usa mobile si no se define
///   desktop: _DesktopBody(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= Breakpoints.desktop) return desktop;
        if (width >= Breakpoints.tablet) return tablet ?? desktop;
        return mobile;
      },
    );
  }
}

/// Centra y limita el ancho del contenido en pantallas anchas.
///
/// En móvil: ocupa todo el ancho.
/// En tablet/desktop: max [maxWidth] centrado con padding lateral.
///
/// Uso:
/// ```dart
/// ResponsiveContent(child: myWidget)
/// ```
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = context.isWide;
    if (!isWide) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Versión de dos columnas para PC.
/// Muestra [left] y [right] en columna en móvil, en fila en desktop.
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double leftFlex;
  final double rightFlex;

  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 24,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, SizedBox(height: spacing), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex.toInt(), child: left),
        SizedBox(width: spacing),
        Expanded(flex: rightFlex.toInt(), child: right),
      ],
    );
  }
}

/// Sidebar de navegación para desktop/tablet.
/// Recibe los mismos [items] que un BottomNavigationBar.
class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppSidebarItem> items;
  final Color? accentColor;

  /// Muestra el nombre de la app / logo en el header.
  final Widget? header;

  /// Widget opcional al final del sidebar (ej. botón cerrar sesión).
  final Widget? footer;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.accentColor,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final selectedBg = accent.withValues(alpha: 0.12);
    final selectedFg = accent;
    final unselectedFg = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            if (header != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: header!,
              ),
              Divider(color: borderColor, height: 1),
            ],

            // ── Nav items ──────────────────────────────────────────────────
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final selected = i == currentIndex;
                  return _SidebarTile(
                    item: item,
                    selected: selected,
                    selectedBg: selectedBg,
                    selectedFg: selectedFg,
                    unselectedFg: unselectedFg,
                    onTap: () => onTap(i),
                  );
                },
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────────
            if (footer != null) ...[
              Divider(color: borderColor, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final AppSidebarItem item;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final Color unselectedFg;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.unselectedFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected ? selectedFg : unselectedFg,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? selectedFg : unselectedFg,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modelo de un ítem del sidebar.
class AppSidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppSidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
