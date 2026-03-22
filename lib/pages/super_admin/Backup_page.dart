// lib/pages/backup/backup_page.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../widgets/notificacion_personalizada.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _service = BackupService();

  bool _cargandoManual   = false;
  bool _cargandoListar   = true;
  bool _restaurando      = false;

  Timer? _timerBackup;

  List<Map<String, dynamic>> _backups = [];
  final List<Map<String, dynamic>> _historialSesion = [];

  @override
  void initState() {
    super.initState();
    _cargarListaBackups();
    _programarBackupDiario();
  }

  @override
  void dispose() {
    _timerBackup?.cancel();
    super.dispose();
  }

  // ── Programa el backup automático a las 12:00am ───────────────
  void _programarBackupDiario() {
    final ahora   = DateTime.now();
    final manana  = DateTime(ahora.year, ahora.month, ahora.day + 1, 0, 0, 0);
    final demora  = manana.difference(ahora);

    _timerBackup = Timer(demora, () {
      _ejecutarBackupAutomatico();
      // Repetir cada 24 horas
      _timerBackup = Timer.periodic(const Duration(hours: 24), (_) {
        _ejecutarBackupAutomatico();
      });
    });
  }

  // ── Ejecuta el backup automático y refresca la lista ─────────
  Future<void> _ejecutarBackupAutomatico() async {
    await _service.backupAutomatico();
    if (mounted) _cargarListaBackups();
  }

  // ── Listar backups en Storage ─────────────────────────────────
  Future<void> _cargarListaBackups() async {
    setState(() => _cargandoListar = true);
    final lista = await _service.listarBackups();
    if (!mounted) return;
    setState(() { _backups = lista; _cargandoListar = false; });
  }

  // ── Descarga manual ───────────────────────────────────────────
  Future<void> _descargarManual() async {
    setState(() => _cargandoManual = true);
    final r = await _service.exportarLocal();
    if (!mounted) return;
    setState(() {
      _cargandoManual = false;
      _historialSesion.insert(0, {
        'fecha':     r['fecha'] ?? '—',
        'archivo':   r['archivo'] ?? '—',
        'totalDocs': r['totalDocs'] ?? 0,
        'exito':     r['exito'] == true,
        'error':     r['error'],
      });
    });
    _snack(
      r['exito'] == true
          ? '✅ Descargado: ${r['archivo']}'
          : '❌ Error: ${r['error']}',
      r['exito'] == true,
    );
  }

  // ── Restaurar desde Storage ───────────────────────────────────
  Future<void> _restaurarDesdeStorage(Map<String, dynamic> backup) async {
    final confirmar = await _mostrarDialogoConfirmar(
      titulo: 'Restaurar backup',
      subtitulo: '${backup['fecha']} — ${backup['size']}',
      advertencia: 'Los datos actuales serán reemplazados por los de esta copia. Esta acción no se puede deshacer.',
    );
    if (!confirmar) return;

    setState(() => _restaurando = true);
    final r = await _service.restaurarDesdeStorage(backup['ruta']);
    if (!mounted) return;
    setState(() => _restaurando = false);

    _snack(
      r['exito'] == true
          ? '✅ Restaurado: ${r['restaurados']} documentos'
          : '❌ Error: ${r['error']}',
      r['exito'] == true,
      duracion: 5,
    );
  }

  // ── Restaurar desde archivo local ─────────────────────────────
  Future<void> _restaurarDesdeArchivo() async {
    final input = html.FileUploadInputElement()..accept = '.json';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;

    final file   = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final confirmar = await _mostrarDialogoConfirmar(
      titulo: 'Restaurar desde archivo',
      subtitulo: file.name,
      advertencia: 'Los datos actuales serán reemplazados. Esta acción no se puede deshacer.',
    );
    if (!confirmar) return;

    setState(() => _restaurando = true);
    final bytes = Uint8List.fromList(reader.result as List<int>);
    final r     = await _service.restaurarDesdeArchivo(bytes);
    if (!mounted) return;
    setState(() => _restaurando = false);

    _snack(
      r['exito'] == true
          ? '✅ Restaurado: ${r['restaurados']} documentos'
          : '❌ Error: ${r['error']}',
      r['exito'] == true,
      duracion: 5,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildColecciones(),
                      const SizedBox(height: 28),
                      _buildBannerUltimoBackupDiario(),
                      const SizedBox(height: 28),
                      _buildAcciones(),
                      const SizedBox(height: 32),
                      _buildCopiasenStorage(),
                      const SizedBox(height: 32),
                      _buildHistorialSesion(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_restaurando)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0B4D3B)),
                    SizedBox(height: 20),
                    Text('Restaurando datos...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Por favor no cierres esta ventana', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0B4D3B), Color(0xFF1A7A57)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF0B4D3B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.backup_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Backup de Base de Datos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
          Text('Copias automáticas + descarga manual + restauración',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      ]),
    );
  }

  // ── Colecciones incluidas ─────────────────────────────────────
  Widget _buildColecciones() {
    final items = [
      ('pedido',        Icons.receipt_long_rounded, const Color(0xFF2563EB)),
      ('productos',     Icons.storefront_rounded,   const Color(0xFF7C3AED)),
      ('usuarios',      Icons.people_rounded,       const Color(0xFFD97706)),
      ('detalle_pedido',Icons.list_alt_rounded,     const Color(0xFF059669)),
      ('venta',         Icons.point_of_sale_rounded,const Color(0xFFDC2626)),
    ];

    return Wrap(
      spacing: 12, runSpacing: 12,
      children: items.map((i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i.$2, color: i.$3, size: 16),
          const SizedBox(width: 8),
          Text(i.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
            child: const Text('✓', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w800)),
          ),
        ]),
      )).toList(),
    );
  }

  // ── Botones de acción ─────────────────────────────────────────
  Widget _buildAcciones() {
    return Row(children: [
      Expanded(
        child: _TarjetaAccion(
          icon: Icons.download_rounded,
          titulo: 'Descargar Backup',
          subtitulo: 'Guarda una copia en tu computador ahora mismo',
          color: const Color(0xFF0B4D3B),
          cargando: _cargandoManual,
          onTap: _descargarManual,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _TarjetaAccion(
          icon: Icons.upload_file_rounded,
          titulo: 'Restaurar desde Archivo',
          subtitulo: 'Sube un archivo .json para volver a esa versión',
          color: const Color(0xFF2563EB),
          cargando: false,
          onTap: _restaurarDesdeArchivo,
          outline: true,
        ),
      ),
    ]);
  }

  // ── Banner último backup diario ───────────────────────────────
  Widget _buildBannerUltimoBackupDiario() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sistema')
          .doc('ultimoBackup')
          .snapshots(),
      builder: (context, snapshot) {
        // Cargando
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _bannerInfo(
            Icons.cloud_sync_rounded,
            'Verificando último backup automático...',
            const Color(0xFF2563EB),
            trailing: const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          );
        }

        // Sin datos — nunca se ha ejecutado
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _bannerInfo(
            Icons.schedule_rounded,
            'El backup automático aún no se ha ejecutado — se hará esta noche a las 12:00am',
            Colors.orange,
          );
        }

        final data  = snapshot.data!.data() as Map<String, dynamic>;
        final exito = data['exito'] == true;
        final fecha = (data['fecha'] as Timestamp?)?.toDate();
        final docs  = data['totalDocs'] ?? 0;
        final kb    = data['tamanoKB']  ?? 0;
        final error = data['error']     as String?;

        String fechaStr = '—';
        if (fecha != null) {
          fechaStr = DateFormat("dd/MM/yyyy 'a las' HH:mm").format(fecha.toLocal());
        }

        if (exito) {
          return _bannerInfo(
            Icons.cloud_done_rounded,
            'Último backup automático: $fechaStr — $docs documentos · $kb KB',
            const Color(0xFF16A34A),
          );
        } else {
          return _bannerInfo(
            Icons.cloud_off_rounded,
            'Último backup falló ($fechaStr): ${error ?? "error desconocido"}',
            Colors.red,
          );
        }
      },
    );
  }

  Widget _bannerInfo(IconData icon, String texto, Color color, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(texto,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
        if (trailing != null) trailing,
      ]),
    );
  }

  // ── Copias en Storage ─────────────────────────────────────────
  Widget _buildCopiasenStorage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Copias automáticas guardadas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const Spacer(),
          TextButton.icon(
            onPressed: _cargarListaBackups,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Actualizar'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0B4D3B)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Últimas 7 copias — se guardan automáticamente cada vez que abres esta sección',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 16),
        if (_cargandoListar)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Color(0xFF0B4D3B)),
          ))
        else if (_backups.isEmpty)
          _estadoVacio('No hay copias en la nube todavía', Icons.cloud_off_rounded)
        else
          ..._backups.map((b) => _BackupCard(
            backup: b,
            onRestaurar: () => _restaurarDesdeStorage(b),
          )),
      ],
    );
  }

  // ── Historial de sesión ───────────────────────────────────────
  Widget _buildHistorialSesion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Descargas de esta sesión',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 16),
        if (_historialSesion.isEmpty)
          _estadoVacio('Sin descargas manuales aún', Icons.history_rounded)
        else
          ..._historialSesion.map((h) => _HistorialTile(item: h)),
      ],
    );
  }

  Widget _estadoVacio(String texto, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(children: [
        Icon(icon, size: 44, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(texto, style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Diálogo de confirmación ───────────────────────────────────
  Future<bool> _mostrarDialogoConfirmar({
    required String titulo,
    required String subtitulo,
    required String advertencia,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          ),
          const SizedBox(width: 12),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subtitulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.red[600], size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(advertencia, style: TextStyle(fontSize: 12, color: Colors.red[700]))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sí, restaurar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _snack(String msg, bool exito, {int duracion = 4}) {
    NotificacionPersonalizada.mostrarSnack(
      context,
      mensaje: msg,
      tipo: exito ? TipoNotificacion.exito : TipoNotificacion.error,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaAccion extends StatelessWidget {
  final IconData icon;
  final String titulo, subtitulo;
  final Color color;
  final bool cargando;
  final bool outline;
  final VoidCallback onTap;

  const _TarjetaAccion({
    required this.icon, required this.titulo, required this.subtitulo,
    required this.color, required this.cargando, required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cargando ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: outline ? Colors.white : color,
          borderRadius: BorderRadius.circular(20),
          border: outline ? Border.all(color: color, width: 2) : null,
          boxShadow: outline ? null : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: outline ? color.withOpacity(0.1) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: cargando
                ? SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: outline ? color : Colors.white))
                : Icon(icon, color: outline ? color : Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: outline ? color : Colors.white)),
            const SizedBox(height: 3),
            Text(subtitulo, style: TextStyle(fontSize: 11, color: outline ? Colors.grey[500] : Colors.white.withOpacity(0.75))),
          ])),
        ]),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  final Map<String, dynamic> backup;
  final VoidCallback onRestaurar;
  const _BackupCard({required this.backup, required this.onRestaurar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(backup['fecha'] ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(backup['size'] ?? '—', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        OutlinedButton.icon(
          onPressed: onRestaurar,
          icon: const Icon(Icons.restore_rounded, size: 15),
          label: const Text('Restaurar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0B4D3B),
            side: const BorderSide(color: Color(0xFF0B4D3B)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}

class _HistorialTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistorialTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final exito = item['exito'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: exito ? const Color(0xFFDCFCE7) : Colors.red.shade100),
      ),
      child: Row(children: [
        Icon(exito ? Icons.check_circle_rounded : Icons.error_rounded,
          color: exito ? const Color(0xFF16A34A) : Colors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exito ? item['archivo'] : 'Error en backup',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (exito)
            Text('${item['totalDocs']} documentos', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          if (!exito && item['error'] != null)
            Text(item['error'], style: const TextStyle(fontSize: 11, color: Colors.red)),
        ])),
        Text(item['fecha'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ]),
    );
  }
}