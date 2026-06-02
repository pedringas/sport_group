import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/pago_model.dart';
import '../../../data/models/cuota_model.dart';

class CuotaDetailPage extends ConsumerWidget {
  final String grupoId;
  final String cuotaId;
  const CuotaDetailPage(
      {super.key, required this.grupoId, required this.cuotaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuotaAsync =
        ref.watch(cuotaProvider((grupoId: grupoId, cuotaId: cuotaId)));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));

    // Use misPagosGrupoProvider (2-field index, no 3-field index dependency)
    // and filter client-side by cuotaId — more reliable for members.
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final misPagosAsync = uid.isNotEmpty
        ? ref.watch(misPagosGrupoProvider((grupoId: grupoId, uid: uid)))
        : const AsyncData<List<PagoModel>>([]);

    final isAdmin = miembroAsync.valueOrNull?.rol.esAdmin ?? false;
    final isTesorero =
        miembroAsync.valueOrNull?.rol == RolMiembro.tesorero;
    final puedeConfirmar = isAdmin || isTesorero;
    final puedeEliminar = puedeConfirmar;
    final gc = ref.watch(grupoColorProvider(grupoId));

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: cuotaAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cuota) {
          if (cuota == null) {
            return const Center(child: Text('Suscripción no encontrada'));
          }
          // Derive miPago from the user's group-wide pagos list
          final miPago = misPagosAsync.valueOrNull
              ?.where((p) => p.cuotaId == cuotaId)
              .firstOrNull;
          final yaPago = miPago?.estado == EstadoPago.aprobado;
          final enValidacion =
              miPago?.estado == EstadoPago.validando ||
                  miPago?.estado == EstadoPago.revision;
          final esperandoTesorero =
              miPago?.estado == EstadoPago.pendiente &&
                  miPago?.metodo == MetodoPago.efectivo;
          final vencida = cuota.vencimiento.isBefore(DateTime.now());

          return CustomScrollView(
            slivers: [
              // â”€â”€ Status banner + back button
              SliverToBoxAdapter(
                child: _StatusBanner(
                  yaPago: yaPago,
                  enValidacion: enValidacion,
                  esperandoTesorero: esperandoTesorero,
                  vencida: vencida && !yaPago,
                  onBack: () => context.pop(),
                  onDelete: puedeEliminar
                      ? () => _confirmDelete(context, ref)
                      : null,
                ),
              ),

              // â”€â”€ Amount hero card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _AmountCard(cuota: cuota, yaPago: yaPago),
                ),
              ),

              // â”€â”€ Details section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _DetailsSection(
                    cuota: cuota,
                    miPago: miPago,
                    vencida: vencida && !yaPago,
                    gc: gc,
                  ),
                ),
              ),

              // â”€â”€ Payment status / actions (member view)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _PaymentSection(
                    miPago: miPago,
                    yaPago: yaPago,
                    enValidacion: enValidacion,
                    esperandoTesorero: esperandoTesorero,
                    grupoId: grupoId,
                    cuotaId: cuotaId,
                    cuota: cuota,
                  ),
                ),
              ),

              // â”€â”€ Tesorero/Admin: pending payments panel
              if (puedeConfirmar)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _PagosPendientesPanel(
                      grupoId: grupoId,
                      cuotaId: cuotaId,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar suscripción'),
        content: const Text(
            '¿Eliminás esta suscripción? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(cuotaRepositoryProvider)
                  .deleteCuota(grupoId, cuotaId);
              if (context.mounted) context.pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Status Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusBanner extends StatelessWidget {
  final bool yaPago;
  final bool enValidacion;
  final bool esperandoTesorero;
  final bool vencida;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  const _StatusBanner({
    required this.yaPago,
    required this.enValidacion,
    required this.esperandoTesorero,
    required this.vencida,
    required this.onBack,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerLabel;

    if (yaPago) {
      bannerColor = AppTheme.good;
      bannerIcon = Icons.check_circle_rounded;
      bannerLabel = 'Suscripción pagada';
    } else if (esperandoTesorero) {
      bannerColor = AppTheme.warning;
      bannerIcon = Icons.hourglass_top_rounded;
      bannerLabel = 'Esperando confirmación del tesorero';
    } else if (enValidacion) {
      bannerColor = AppTheme.info;
      bannerIcon = Icons.hourglass_top_rounded;
      bannerLabel = 'Comprobante en validación';
    } else if (vencida) {
      bannerColor = AppTheme.danger;
      bannerIcon = Icons.warning_amber_rounded;
      bannerLabel = 'Suscripción vencida';
    } else {
      bannerColor = AppTheme.warning;
      bannerIcon = Icons.payments_outlined;
      bannerLabel = 'Pendiente de pago';
    }

    return Container(
      color: bannerColor.withValues(alpha: 0.08),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 4,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          Icon(bannerIcon, size: 16, color: bannerColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              bannerLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: bannerColor,
              ),
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Amount Card (dark) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AmountCard extends StatelessWidget {
  final CuotaModel cuota;
  final bool yaPago;

  const _AmountCard({required this.cuota, required this.yaPago});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cuota.tituloConNumero,
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (cuota.esRecurrente)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat_rounded,
                          size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Recurrente',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${cuota.monto.toStringAsFixed(0)}',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 42,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: Colors.white54),
              const SizedBox(width: 5),
              Text(
                'Vence el ${DateFormat('dd/MM/yyyy').format(cuota.vencimiento)}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (cuota.descripcion != null) ...[
            const SizedBox(height: 8),
            Text(
              cuota.descripcion!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// â”€â”€ Details Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DetailsSection extends StatelessWidget {
  final CuotaModel cuota;
  final PagoModel? miPago;
  final bool vencida;
  final Color gc;

  const _DetailsSection({
    required this.cuota,
    required this.miPago,
    required this.vencida,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.attach_money_rounded,
            label: 'Monto',
            value: '\$${cuota.monto.toStringAsFixed(0)}',
            valueColor: gc,
          ),
          const Divider(height: 1, color: AppTheme.border),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Vencimiento',
            value: DateFormat('dd/MM/yyyy').format(cuota.vencimiento),
            valueColor: vencida ? AppTheme.danger : null,
          ),
          if (cuota.esRecurrente) ...[
            const Divider(height: 1, color: AppTheme.border),
            _DetailRow(
              icon: Icons.repeat_rounded,
              label: 'Frecuencia',
              value: cuota.frecuencia?.label ?? 'Mensual',
            ),
          ],
          if (miPago?.updatedAt != null &&
              miPago?.estado == EstadoPago.aprobado) ...[
            const Divider(height: 1, color: AppTheme.border),
            _DetailRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Aprobado el',
              value: DateFormat('dd/MM/yyyy').format(miPago!.updatedAt!),
              valueColor: AppTheme.good,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.text,
              ),
            ),
          ],
        ),
    );
  }
}

// â”€â”€ Payment Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PaymentSection extends ConsumerWidget {
  final PagoModel? miPago;
  final bool yaPago;
  final bool enValidacion;
  final bool esperandoTesorero;
  final String grupoId;
  final String cuotaId;
  final CuotaModel cuota;

  const _PaymentSection({
    required this.miPago,
    required this.yaPago,
    required this.enValidacion,
    required this.esperandoTesorero,
    required this.grupoId,
    required this.cuotaId,
    required this.cuota,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    if (yaPago) {
      return _PaidCard(miPago: miPago, gc: gc);
    }
    if (esperandoTesorero) {
      return _EsperaAprobacionCard(
        miPago: miPago!,
        grupoId: grupoId,
      );
    }
    if (enValidacion) {
      return _ValidationCard(miPago: miPago, gc: gc);
    }

    // Not paid ”” show payment options
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Opciones de pago',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 12),
        SGPillButton(
          label: 'Registrar pago en efectivo',
          icon: Icons.payments_rounded,
          expand: true,
          onPressed: () => _showRegistrarEfectivo(context, ref),
        ),
        const SizedBox(height: 10),
        SGPillButton(
          label: 'Subir comprobante manual',
          icon: Icons.upload_rounded,
          tone: SGTone.outline,
          expand: true,
          onPressed: () =>
              context.push('/group/$grupoId/cuota/$cuotaId/pay/manual'),
        ),
      ],
    );
  }

  void _showRegistrarEfectivo(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _RegistrarEfectivoSheet(
          grupoId: grupoId,
          cuotaId: cuotaId,
          cuota: cuota,
        ),
      ),
    );
  }
}

// â”€â”€ Registrar Efectivo Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RegistrarEfectivoSheet extends ConsumerStatefulWidget {
  final String grupoId;
  final String cuotaId;
  final CuotaModel cuota;

  const _RegistrarEfectivoSheet({
    required this.grupoId,
    required this.cuotaId,
    required this.cuota,
  });

  @override
  ConsumerState<_RegistrarEfectivoSheet> createState() =>
      _RegistrarEfectivoSheetState();
}

class _RegistrarEfectivoSheetState
    extends ConsumerState<_RegistrarEfectivoSheet> {
  final _notaCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(cuotaRepositoryProvider).registrarPagoEfectivo(
            grupoId: widget.grupoId,
            cuotaId: widget.cuotaId,
            usuarioUid: user.uid,
            usuarioNombre: user.displayName ?? user.email ?? 'Miembro',
            monto: widget.cuota.monto,
            nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Registrar pago en efectivo',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'El tesorero o administrador confirmará el pago.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          // Amount display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_rounded, size: 18, color: gc),
                const SizedBox(width: 10),
                Text(
                  'Monto: \$${widget.cuota.monto.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: gc,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Optional note
          TextField(
            controller: _notaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Ej: Pagué el martes con García',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            maxLines: 2,
            maxLength: 120,
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_loading ? 'Registrando...' : 'Confirmar registro'),
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Espera Aprobación Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EsperaAprobacionCard extends ConsumerWidget {
  final PagoModel miPago;
  final String grupoId;

  const _EsperaAprobacionCard({
    required this.miPago,
    required this.grupoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amber = AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hourglass_top_rounded, color: amber, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'Pago registrado',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'El tesorero o administrador lo\nconfirmará a la brevedad.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            'Registrado el ${DateFormat('dd/MM/yyyy').format(miPago.createdAt)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (miPago.nota != null && miPago.nota!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      miPago.nota!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Cancel option
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Cancelar registro'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.4)),
              minimumSize: const Size(double.infinity, 44),
              textStyle: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cancelar registro'),
                  content: const Text(
                      '¿Querés cancelar este registro de pago en efectivo?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sí, cancelar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(cuotaRepositoryProvider)
                    .deletePago(miPago.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Panel del Tesorero/Admin: todos los miembros con su estado ───────────────

class _PagosPendientesPanel extends ConsumerWidget {
  final String grupoId;
  final String cuotaId;

  const _PagosPendientesPanel({
    required this.grupoId,
    required this.cuotaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagosAsync =
        ref.watch(pagosDeCuotaProvider((grupoId: grupoId, cuotaId: cuotaId)));
    final miembrosAsync = ref.watch(miembrosProvider(grupoId));
    final cuotaAsync =
        ref.watch(cuotaProvider((grupoId: grupoId, cuotaId: cuotaId)));
    final gc = ref.watch(grupoColorProvider(grupoId));

    final pagos = pagosAsync.valueOrNull ?? [];
    final miembros = miembrosAsync.valueOrNull ?? [];
    final cuota = cuotaAsync.valueOrNull;
    final vencida = cuota?.vencimiento.isBefore(DateTime.now()) ?? false;

    if (miembros.isEmpty) return const SizedBox.shrink();

    // Build per-member payment status
    PagoModel? pagoFor(String uid) => pagos
        .where((p) => p.usuarioUid == uid)
        .fold<PagoModel?>(
          null,
          (best, p) {
            if (best == null) return p;
            // Prefer aprobado > validando/revision > pendiente
            if (p.estado == EstadoPago.aprobado) return p;
            if (best.estado == EstadoPago.aprobado) return best;
            return p;
          },
        );

    // Categorise
    final porConfirmar = <({MiembroModel m, PagoModel p})>[];
    final aprobados = <({MiembroModel m, PagoModel p})>[];
    final sinPagar = <MiembroModel>[];

    for (final m in miembros) {
      final p = pagoFor(m.uid);
      if (p == null) {
        sinPagar.add(m);
      } else if (p.estado == EstadoPago.aprobado) {
        aprobados.add((m: m, p: p));
      } else {
        // pendiente, validando, revision — needs tesorero action
        porConfirmar.add((m: m, p: p));
      }
    }

    // Sort alphabetically within each group
    porConfirmar.sort((a, b) => a.m.nombreCompleto.compareTo(b.m.nombreCompleto));
    aprobados.sort((a, b) => a.m.nombreCompleto.compareTo(b.m.nombreCompleto));
    sinPagar.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ── Section title
        Text(
          'Estado de pagos por miembro',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.text,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),

        // ── Por confirmar
        if (porConfirmar.isNotEmpty) ...[
          _SectionHeader(
            label: 'Pendientes de confirmación',
            count: porConfirmar.length,
            color: AppTheme.warning,
          ),
          const SizedBox(height: 6),
          ...porConfirmar.map((e) => _PagoPendienteRow(
                pago: e.p,
                miembro: e.m,
                grupoId: grupoId,
              )),
          const SizedBox(height: 12),
        ],

        // ── Aprobados
        if (aprobados.isNotEmpty) ...[
          _SectionHeader(
            label: 'Pagaron',
            count: aprobados.length,
            color: AppTheme.good,
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: aprobados.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                return Column(
                  children: [
                    if (idx > 0)
                      const Divider(height: 1, color: AppTheme.border,
                          indent: 50, endIndent: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          _MiniAvatar(nombre: item.m.nombreCompleto,
                              avatarUrl: item.m.avatarUrl, gc: gc),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.m.nombreCompleto,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: AppTheme.good),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM').format(
                                item.p.updatedAt ?? item.p.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Sin pagar
        if (sinPagar.isNotEmpty) ...[
          _SectionHeader(
            label: vencida ? 'Adeudan (vencida)' : 'Sin pagar',
            count: sinPagar.length,
            color: vencida ? AppTheme.danger : AppTheme.textMuted,
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: sinPagar.asMap().entries.map((e) {
                final idx = e.key;
                final m = e.value;
                return Column(
                  children: [
                    if (idx > 0)
                      const Divider(height: 1, color: AppTheme.border,
                          indent: 50, endIndent: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          _MiniAvatar(nombre: m.nombreCompleto,
                              avatarUrl: m.avatarUrl, gc: gc),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.nombreCompleto,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: (vencida ? AppTheme.danger : AppTheme.textMuted)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vencida ? 'Vencida' : 'Sin pagar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: vencida
                                    ? AppTheme.danger
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.text)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String nombre;
  final String? avatarUrl;
  final Color gc;
  const _MiniAvatar(
      {required this.nombre, required this.avatarUrl, required this.gc});

  @override
  Widget build(BuildContext context) {
    return SGAvatar(
      name: nombre,
      imageUrl: avatarUrl,
      size: 30,
      background: gc,
    );
  }
}

class _PagoPendienteRow extends ConsumerStatefulWidget {
  final PagoModel pago;
  final MiembroModel miembro;
  final String grupoId;

  const _PagoPendienteRow({
    required this.pago,
    required this.miembro,
    required this.grupoId,
  });

  @override
  ConsumerState<_PagoPendienteRow> createState() => _PagoPendienteRowState();
}

class _PagoPendienteRowState extends ConsumerState<_PagoPendienteRow> {
  bool _loading = false;

  Future<void> _confirmar(EstadoPago nuevoEstado) async {
    setState(() => _loading = true);
    try {
      await ref.read(cuotaRepositoryProvider).confirmarPago(
            pagoId: widget.pago.id,
            nuevoEstado: nuevoEstado,
            miembroUid: widget.pago.usuarioUid,
            grupoId: widget.grupoId,
            monto: widget.pago.montoEsperado,
          );
      if (mounted) {
        final label =
            nuevoEstado == EstadoPago.aprobado ? 'aprobado' : 'rechazado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago $label')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final pago = widget.pago;
    final fmt = NumberFormat('#,##0', 'es_AR');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SGAvatar(
                name: widget.miembro.nombreCompleto,
                imageUrl: widget.miembro.avatarUrl,
                size: 36,
                background: gc,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.miembro.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    Row(children: [
                      if (pago.estado == EstadoPago.validando ||
                          pago.estado == EstadoPago.revision)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Comprobante',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.info)),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Efectivo',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warning)),
                        ),
                      Text(
                        DateFormat('dd/MM · HH:mm')
                            .format(pago.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ]),
                  ],
                ),
              ),
              Text(
                '\$${fmt.format(pago.montoEsperado.toInt())}',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          // Optional note
          if (pago.nota != null && pago.nota!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pago.nota!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                // Ver comprobante (if uploaded)
                if (pago.comprobanteUrl != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_search_rounded, size: 15),
                    label: const Text('Ver comprobante'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => launchUrl(
                        Uri.parse(pago.comprobanteUrl!),
                        mode: LaunchMode.platformDefault,
                        webOnlyWindowName: '_blank'),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(
                              color: AppTheme.danger.withValues(alpha: 0.4)),
                          minimumSize: const Size(0, 40),
                          textStyle: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _confirmar(EstadoPago.revision),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: const Text('Aprobar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.good,
                          minimumSize: const Size(0, 40),
                          textStyle: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _confirmar(EstadoPago.aprobado),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  final PagoModel? miPago;
  final Color gc;
  const _PaidCard({this.miPago, required this.gc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.good.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.good.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.good.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppTheme.good, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Suscripción pagada!',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.text,
            ),
          ),
          if (miPago?.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Aprobado el ${DateFormat('dd/MM/yyyy').format(miPago!.updatedAt!)}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
          if (miPago?.comprobanteUrl != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(miPago!.comprobanteUrl!),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Ver comprobante',
                      style: TextStyle(
                          color: gc,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  final PagoModel? miPago;
  final Color gc;
  const _ValidationCard({this.miPago, required this.gc});

  @override
  Widget build(BuildContext context) {
    final isRevision =
        miPago?.estado == EstadoPago.revision;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: AppTheme.info, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            isRevision
                ? 'En revisión manual'
                : 'Comprobante en validación',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRevision
                ? 'El tesorero revisará tu comprobante pronto'
                : 'Verificando tu transferencia automáticamente',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          if (miPago?.comprobanteUrl != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(miPago!.comprobanteUrl!),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Ver comprobante enviado',
                      style: TextStyle(
                          color: gc,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
