import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/repartidor_model.dart';
import '../../domain/repositories/repartidor_repository.dart';
import 'add_edit_repartidor_screen.dart';
import 'reparto_historico_screen.dart';

class RepartoScreen extends StatefulWidget {
  const RepartoScreen({super.key});

  @override
  State<RepartoScreen> createState() => _RepartoScreenState();
}

class _RepartoScreenState extends State<RepartoScreen> {
  final _repo = RepartidorRepository();
  List<RepartidorModel> _repartidores = [];
  bool _isLoading = true;
  late String _shopId;

  @override
  void initState() {
    super.initState();
    _shopId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _repartidores = await _repo.getRepartidores(_shopId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _add() async {
    final result = await Navigator.push<RepartidorModel>(
      context,
      MaterialPageRoute(
          builder: (_) => const AddEditRepartidorScreen()),
    );
    if (result != null) {
      setState(() => _repartidores.insert(0, result));
    }
  }

  Future<void> _edit(RepartidorModel r) async {
    final result = await Navigator.push<RepartidorModel>(
      context,
      MaterialPageRoute(
          builder: (_) => AddEditRepartidorScreen(repartidor: r)),
    );
    if (result != null) {
      final idx = _repartidores.indexWhere((x) => x.id == r.id);
      if (idx >= 0) setState(() => _repartidores[idx] = result);
    }
  }

  Future<void> _togglePause(RepartidorModel r) async {
    final newStatus = r.isActive ? 'paused' : 'active';
    final ok = await _repo.setStatus(r.id!, newStatus);
    if (ok && mounted) {
      final idx = _repartidores.indexWhere((x) => x.id == r.id);
      if (idx >= 0) {
        setState(() =>
            _repartidores[idx] = r.copyWith(status: newStatus));
      }
    }
  }

  Future<void> _delete(RepartidorModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar repartidor'),
        content: Text(
            '¿Eliminar a ${r.name}? Los pedidos asignados quedarán sin repartidor.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _repo.deleteRepartidor(r.id!);
      if (ok && mounted) {
        setState(() => _repartidores.removeWhere((x) => x.id == r.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activos = _repartidores.where((r) => r.isActive).toList();
    final pausados = _repartidores.where((r) => !r.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.black87, size: 20),
                            ),
                          ),
                        const Text(
                          'Reparto',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const Spacer(),
                        // Histórico button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RepartoHistoricoScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded,
                                    color: AppTheme.primary, size: 16),
                                SizedBox(width: 5),
                                Text(
                                  'Histórico',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_repartidores.length} repartidor${_repartidores.length == 1 ? '' : 'es'} registrado${_repartidores.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (activos.isNotEmpty) ...[
                      _sectionLabel('Activos', activos.length,
                          const Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      ...activos.map((r) => _buildCard(r)),
                    ],
                    if (pausados.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(
                          'En pausa', pausados.length, const Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      ...pausados.map((r) => _buildCard(r)),
                    ],
                    if (_repartidores.isEmpty)
                      _buildEmptyState(),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo repartidor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sectionLabel(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration:
                    BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: color.withValues(alpha: 0.2),
            indent: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(RepartidorModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: r.isActive
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_rounded,
                color:
                    r.isActive ? AppTheme.primary : Colors.grey.shade400,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (r.vehicleName != null || r.vehiclePlates != null)
                    Text(
                      [
                        if (r.vehicleName != null) r.vehicleName!,
                        if (r.vehiclePlates != null) r.vehiclePlates!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit(r);
                if (v == 'pause') _togglePause(r);
                if (v == 'delete') _delete(r);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 10),
                    const Text('Editar'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'pause',
                  child: Row(children: [
                    Icon(
                      r.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 10),
                    Text(r.isActive ? 'Pausar' : 'Activar'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.more_vert,
                    color: Color(0xFFBDBDBD), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delivery_dining_rounded,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin repartidores registrados',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFBDBDBD)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Agrega tu primer repartidor con el botón de abajo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }
}
