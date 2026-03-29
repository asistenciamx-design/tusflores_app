import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/models/repartidor_model.dart';
import '../../domain/repositories/repartidor_repository.dart';

/// Bottom sheet para asignar un repartidor a un pedido.
///
/// Retorna un [_AssignResult] si el usuario confirma.
class AssignRepartidorSheet extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String? currentRepartidorId;
  final double? currentDeliveryAmount;
  final double shippingCost;
  final bool autoTransferShipping; // from shop settings

  const AssignRepartidorSheet({
    super.key,
    required this.orderId,
    required this.shopId,
    this.currentRepartidorId,
    this.currentDeliveryAmount,
    required this.shippingCost,
    this.autoTransferShipping = false,
  });

  @override
  State<AssignRepartidorSheet> createState() => _AssignRepartidorSheetState();
}

class _AssignRepartidorSheetState extends State<AssignRepartidorSheet> {
  final _repo = RepartidorRepository();
  List<RepartidorModel> _all = [];
  List<RepartidorModel> _filtered = [];
  bool _loading = true;
  bool _saving = false;

  String? _selectedId;
  late TextEditingController _searchCtrl;
  late TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentRepartidorId;
    final initialAmount = widget.currentDeliveryAmount ??
        (widget.autoTransferShipping ? widget.shippingCost : 0.0);
    _amountCtrl = TextEditingController(
        text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '');
    _searchCtrl = TextEditingController();
    _loadRepartidores();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRepartidores() async {
    final list = await _repo.getRepartidores(widget.shopId);
    _all = list.where((r) => r.isActive).toList();
    _filtered = List.from(_all);
    if (mounted) setState(() => _loading = false);
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = _all
          .where((r) =>
              r.name.toLowerCase().contains(lower) ||
              (r.vehicleName?.toLowerCase().contains(lower) ?? false))
          .toList();
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final amount = double.tryParse(_amountCtrl.text.trim()) ??
        (widget.autoTransferShipping ? widget.shippingCost : 0.0);
    final ok = await _repo.assignToOrder(
      orderId: widget.orderId,
      repartidorId: _selectedId,
      deliveryAmount: _selectedId != null ? amount : null,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.pop(context, _AssignResult(
          repartidorId: _selectedId,
          deliveryAmount: _selectedId != null ? amount : null,
          repartidorName: _selectedId != null
              ? _all.firstWhere((r) => r.id == _selectedId,
                      orElse: () => _all.first)
                  .name
              : null,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la asignación.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRepartidor = _selectedId != null
        ? _all.where((r) => r.id == _selectedId).firstOrNull
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                const Text(
                  'Asignar Repartidor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                const Spacer(),
                if (_selectedId != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedId = null),
                    child: const Text('Quitar',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),

          // Current assignment banner
          if (selectedRepartidor != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedRepartidor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 18),
                ],
              ),
            ),

          // Amount field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto para el repartidor',
                prefixText: '${CurrencyCache.symbol} ',
                suffixText: CurrencyCache.code,
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar repartidor…',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[400], size: 20),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Repartidores list
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child:
                  CircularProgressIndicator(color: AppTheme.primary),
            )
          else if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sin repartidores activos',
                style: TextStyle(color: Color(0xFFBDBDBD)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final r = _filtered[i];
                  final isSelected = r.id == _selectedId;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delivery_dining_rounded,
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      r.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textLight,
                      ),
                    ),
                    subtitle: (r.vehicleName != null || r.vehiclePlates != null)
                        ? Text(
                            [
                              if (r.vehicleName != null) r.vehicleName!,
                              if (r.vehiclePlates != null) r.vehiclePlates!,
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9E9E9E)),
                          )
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary, size: 20)
                        : null,
                    onTap: () {
                      setState(() => _selectedId = r.id);
                      // Auto-fill amount if transfer is enabled
                      if (widget.autoTransferShipping &&
                          (_amountCtrl.text.isEmpty ||
                              double.tryParse(_amountCtrl.text) == 0)) {
                        _amountCtrl.text =
                            widget.shippingCost.toStringAsFixed(0);
                      }
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _selectedId == null
                            ? 'Sin repartidor'
                            : 'Confirmar asignación',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Result returned to the caller after successful assignment.
class _AssignResult {
  final String? repartidorId;
  final double? deliveryAmount;
  final String? repartidorName;

  const _AssignResult({
    this.repartidorId,
    this.deliveryAmount,
    this.repartidorName,
  });
}

/// Public typedef for the result so the caller can import it.
typedef AssignResult = _AssignResult;
