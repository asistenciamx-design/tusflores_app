import 'package:flutter/material.dart';
import '../../domain/models/proveedor_models.dart';

/// Pantalla de selección visual completa para una categoría del Maestro.
/// Muestra TODAS las variantes (sub-categorías + sub-colores) en una sola
/// pantalla con imagen/color visual. Retorna el Set<MaestroSelection>
/// actualizado al hacer pop.
class ProveedorMaestroDetailScreen extends StatefulWidget {
  final MaestroCategory cat;
  final List<MaestroSubCategory> subs;
  final Map<String, List<MaestroSubColor>> subColors;
  final Set<MaestroSelection> existing;
  final Set<MaestroSelection> initialSelections;

  const ProveedorMaestroDetailScreen({
    super.key,
    required this.cat,
    required this.subs,
    required this.subColors,
    required this.existing,
    required this.initialSelections,
  });

  @override
  State<ProveedorMaestroDetailScreen> createState() =>
      _ProveedorMaestroDetailScreenState();
}

class _ProveedorMaestroDetailScreenState
    extends State<ProveedorMaestroDetailScreen> {
  late Set<MaestroSelection> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelections);
  }

  bool _isExisting(MaestroSelection sel) => widget.existing.contains(sel);
  bool _isNew(MaestroSelection sel) => _selected.contains(sel);

  void _toggle(MaestroSelection sel) {
    if (_isExisting(sel)) return;
    setState(() {
      if (_selected.contains(sel)) {
        _selected.remove(sel);
      } else {
        _selected.add(sel);
      }
    });
  }

  void _popWithResult() => Navigator.pop(context, _selected);

  // Contar nuevas selecciones solo para esta categoría
  int get _newCount {
    int n = 0;
    for (final s in _selected) {
      if (s.categoryId == widget.cat.id) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF8FF),
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            ..._buildContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildAppBar() {
    final cat = widget.cat;
    final newCount = _newCount;

    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFFFBF8FF),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 100,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF500088)),
        onPressed: _popWithResult,
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 16, 14),
        title: Row(
          children: [
            if (cat.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  cat.imageUrl!,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _catPlaceholder(30),
                ),
              )
            else
              _catPlaceholder(30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cat.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF500088),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (newCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF500088).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$newCount nuevos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF500088),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final cat = widget.cat;
    final subs = widget.subs;

    if (subs.isEmpty) {
      // Categoría sin variantes — selección directa
      return [
        SliverToBoxAdapter(child: _buildDirectCategoryCard(cat)),
      ];
    }

    final slivers = <Widget>[];

    for (final sub in subs) {
      final colors = widget.subColors[sub.id] ?? [];

      // Header de sub-categoría
      slivers.add(
        SliverToBoxAdapter(
          child: _buildSubCatHeader(sub, colors),
        ),
      );

      if (colors.isEmpty) {
        // Sub-cat seleccionable directamente (sin sub-colores)
        slivers.add(
          SliverToBoxAdapter(
            child: _buildDirectSubCatCard(cat, sub),
          ),
        );
      } else {
        // Grid de sub-colores
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildColorCard(cat, sub, colors[i]),
                childCount: colors.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
            ),
          ),
        );
      }
    }

    return slivers;
  }

  Widget _buildSubCatHeader(
      MaestroSubCategory sub, List<MaestroSubColor> colors) {
    // Contar seleccionados en esta sub-cat
    int selCount = 0;
    for (final s in {...widget.existing, ..._selected}) {
      if (s.subCategoryId == sub.id) selCount++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          if (sub.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                sub.imageUrl!,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _subCatPlaceholder(sub),
              ),
            )
          else
            _subCatPlaceholder(sub),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (colors.isNotEmpty)
                  Text(
                    '${colors.length} color${colors.length != 1 ? 'es' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          if (selCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$selCount ✓',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tarjeta visual de un sub-color — usa el hex como fondo degradado.
  Widget _buildColorCard(
      MaestroCategory cat, MaestroSubCategory sub, MaestroSubColor c) {
    final sel = MaestroSelection(
      categoryId: cat.id,
      subCategoryId: sub.id,
      subColorId: c.id,
    );
    final isExisting = _isExisting(sel);
    final isNew = _isNew(sel);
    final isSelected = isExisting || isNew;

    final baseColor =
        c.color != null && c.color!.isNotEmpty ? _hexColor(c.color!) : null;

    return GestureDetector(
      onTap: () => _toggle(sel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExisting
                ? const Color(0xFF059669)
                : isNew
                    ? const Color(0xFF500088)
                    : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo: imagen de sub-categoría si existe, sino color hex
              if (sub.imageUrl != null)
                Image.network(
                  sub.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _colorBackground(baseColor, sub),
                )
              else
                _colorBackground(baseColor, sub),

              // Overlay de color para tonalizar la imagen con el hex
              if (baseColor != null && sub.imageUrl != null)
                Container(
                  color: baseColor.withValues(alpha: 0.30),
                ),

              // Gradiente oscuro inferior para legibilidad
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),

              // Nombre del color
              Positioned(
                left: 10,
                right: 36,
                bottom: 10,
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                          blurRadius: 6,
                          color: Colors.black54,
                          offset: Offset(0, 1))
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Dot de color (si existe hex)
              if (baseColor != null)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),

              // Checkbox top-right
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isExisting
                        ? const Color(0xFF059669)
                        : isNew
                            ? const Color(0xFF500088)
                            : Colors.white.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorBackground(Color? baseColor, MaestroSubCategory sub) {
    if (baseColor != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(baseColor, 0.15),
              _darken(baseColor, 0.12),
            ],
          ),
        ),
      );
    }
    // Sin color ni imagen: gradiente floral por defecto
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.6),
            const Color(0xFF3B0764).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildDirectCategoryCard(MaestroCategory cat) {
    final sel = MaestroSelection(categoryId: cat.id);
    final isExisting = _isExisting(sel);
    final isNew = _isNew(sel);
    final isSelected = isExisting || isNew;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => _toggle(sel),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF500088).withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF500088)
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cat.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              _checkboxWidget(isExisting: isExisting, isNew: isNew),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectSubCatCard(MaestroCategory cat, MaestroSubCategory sub) {
    final sel =
        MaestroSelection(categoryId: cat.id, subCategoryId: sub.id);
    final isExisting = _isExisting(sel);
    final isNew = _isNew(sel);
    final isSelected = isExisting || isNew;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () => _toggle(sel),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF500088).withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF500088)
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sub.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              _checkboxWidget(isExisting: isExisting, isNew: isNew),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkboxWidget(
      {required bool isExisting, required bool isNew}) {
    if (!isExisting && !isNew) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.grey.shade300),
        ),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color:
            isExisting ? const Color(0xFF059669) : const Color(0xFF500088),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Icon(Icons.check, size: 15, color: Colors.white),
    );
  }

  Widget? _buildBottomBar() {
    final newCount = _newCount;
    if (newCount == 0) return null;

    return Container(
      color: const Color(0xFFFBF8FF),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: ElevatedButton(
        onPressed: _popWithResult,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF500088),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          'Confirmar $newCount producto${newCount != 1 ? 's' : ''} seleccionados',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Placeholders ───────────────────────────────────────────────────────────

  Widget _catPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF8),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        Icons.local_florist_rounded,
        size: size * 0.5,
        color: const Color(0xFF500088).withValues(alpha: 0.3),
      ),
    );
  }

  Widget _subCatPlaceholder(MaestroSubCategory sub) {
    final baseColor = sub.color != null && sub.color!.isNotEmpty
        ? _hexColor(sub.color!)
        : const Color(0xFF7C3AED);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.3),
            baseColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.local_florist_rounded,
        size: 22,
        color: baseColor.withValues(alpha: 0.6),
      ),
    );
  }

  // ── Color utilities ────────────────────────────────────────────────────────

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey.shade400;
    }
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
