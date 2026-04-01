import 'package:flutter/material.dart';

class ProveedorDashboardScreen extends StatelessWidget {
  const ProveedorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Panel Administrativo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B21),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona tu taller floral y pedidos mayoristas.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // ── Resumen cards ──────────────────────────────────────────
              _MetricCard(
                label: 'VENTAS TOTALES',
                value: '\$12,500',
                trend: '+12%',
                trendPositive: true,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: 'PEDIDOS NUEVOS',
                value: '15',
              ),
              const SizedBox(height: 12),
              // Card morada destacada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B21A8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCTOS VENDIDOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '240',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Pedidos recientes ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pedidos recientes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Ver todos',
                      style: TextStyle(
                        color: Color(0xFF500088),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _OrderCard(
                shopName: 'Floreria El Rosal',
                detail: '15 productos \u2022 Hace 20 min',
                amount: '\$1,200',
                status: 'ENVIADO',
                statusColor: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 10),
              _OrderCard(
                shopName: 'Orquideas de Polanco',
                detail: '24 productos \u2022 Hace 1 hora',
                amount: '\$2,450',
                status: 'PROCESANDO',
                statusColor: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 10),
              _OrderCard(
                shopName: 'Taller Floral',
                detail: '10 productos \u2022 Hace 3 horas',
                amount: '\$890',
                status: 'ENVIADO',
                statusColor: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 32),

              // ── Stock de Flores ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2FB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock de Flores',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    _StockBar(name: 'Rosas', qty: 42, pct: 0.85, low: false),
                    _StockBar(name: 'Tulipanes', qty: 8, pct: 0.15, low: true),
                    _StockBar(name: 'Lilis', qty: 28, pct: 0.60, low: false),
                    _StockBar(name: 'Girasoles', qty: 5, pct: 0.10, low: true),
                    _StockBar(name: 'Hortensias', qty: 33, pct: 0.75, low: false),
                    _StockBar(name: 'Claveles', qty: 21, pct: 0.45, low: false),
                    _StockBar(name: 'Orquideas', qty: 9, pct: 0.18, low: true),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_rounded),
                        label: const Text('Anadir Inventario',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF500088),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final bool trendPositive;

  const _MetricCard({
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
              ),
              if (trend != null) ...[
                const SizedBox(width: 12),
                Row(
                  children: [
                    Icon(
                      trendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: trendPositive
                          ? const Color(0xFF22C55E)
                          : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: trendPositive
                            ? const Color(0xFF22C55E)
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String shopName;
  final String detail;
  final String amount;
  final String status;
  final Color statusColor;

  const _OrderCard({
    required this.shopName,
    required this.detail,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(detail,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(amount,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E1EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF4C4452), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockBar extends StatelessWidget {
  final String name;
  final int qty;
  final double pct;
  final bool low;

  const _StockBar({
    required this.name,
    required this.qty,
    required this.pct,
    required this.low,
  });

  @override
  Widget build(BuildContext context) {
    final color = low ? const Color(0xFFBA1A1A) : const Color(0xFF006D30);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E1EA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 55,
            child: Text(
              '$qty pqts',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
