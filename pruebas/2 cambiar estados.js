// ============================================================
//  SCRIPT 2 — Cambiar estados de pedidos masivamente
//  Granero del Norte | el-gran-molino-6642d
// ============================================================
//
//  USO:
//    node 2_cambiar_estados.js                    → pendiente → confirmado (todos)
//    node 2_cambiar_estados.js confirmado entregado  → confirmado → entregado
//    node 2_cambiar_estados.js pendiente cancelado   → pendiente → cancelado
//    node 2_cambiar_estados.js pendiente confirmado 10 → solo los primeros 10
//
//  ESTADOS VÁLIDOS: pendiente | confirmado | entregado | cancelado
// ============================================================

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'el-gran-molino-6642d',
});

const db = admin.firestore();

const ESTADOS_VALIDOS = ['pendiente', 'confirmado', 'entregado', 'cancelado'];

async function generarNumeroVenta() {
  const contadorRef = db.collection('config').doc('contadorVentas');
  return db.runTransaction(async tx => {
    const snap = await tx.get(contadorRef);
    const nuevo = ((snap.data()?.ultimo ?? 0)) + 1;
    tx.set(contadorRef, { ultimo: nuevo });
    const fecha = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    return `VEN-${fecha}-${String(nuevo).padStart(4, '0')}`;
  });
}

async function cambiarEstado(pedidoDoc, nuevoEstado, idAdmin = 'script_prueba') {
  const pedido = pedidoDoc.data();
  const pedidoRef = db.collection('pedido').doc(pedidoDoc.id);

  const historial = [...(pedido.historialEstados ?? [])];
  historial.push({
    estado:          nuevoEstado,
    estadoAnterior:  pedido.estado,
    fecha:           admin.firestore.FieldValue.serverTimestamp(),
    cambiadoPor:     idAdmin,
  });

  const batch = db.batch();

  batch.update(pedidoRef, {
    estado:              nuevoEstado,
    estadoAnterior:      pedido.estado,
    historialEstados:    historial,
    fechaActualizacion:  admin.firestore.FieldValue.serverTimestamp(),
    actualizado_por:     idAdmin,
    cancelado:           nuevoEstado === 'cancelado',
  });

  // Si pasa a entregado → crear venta
  if (nuevoEstado === 'entregado') {
    const ventaRef    = db.collection('venta').doc();
    const numeroVenta = await generarNumeroVenta();

    batch.set(ventaRef, {
      idVenta:       ventaRef.id,
      numeroVenta,
      idPedido:      pedidoDoc.id,
      numeroPedido:  pedido.numeroPedido,
      idCliente:     pedido.idCliente,
      nombreCliente: pedido.nombreCliente,
      fechaVenta:    admin.firestore.FieldValue.serverTimestamp(),
      total:         pedido.total,
      registradoPor: idAdmin,
      año:  new Date().getFullYear(),
      mes:  new Date().getMonth() + 1,
      dia:  new Date().getDate(),
      _esDatosDePrueba: pedido._esDatosDePrueba ?? false,
    });

    batch.update(pedidoRef, {
      fechaPago: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

async function main() {
  const estadoOrigen  = process.argv[2] || 'pendiente';
  const estadoDestino = process.argv[3] || 'confirmado';
  const limite        = parseInt(process.argv[4]) || 999;

  if (!ESTADOS_VALIDOS.includes(estadoOrigen)) {
    console.error(`❌ Estado origen inválido: "${estadoOrigen}"`);
    console.error(`   Usa: ${ESTADOS_VALIDOS.join(' | ')}`);
    process.exit(1);
  }
  if (!ESTADOS_VALIDOS.includes(estadoDestino)) {
    console.error(`❌ Estado destino inválido: "${estadoDestino}"`);
    console.error(`   Usa: ${ESTADOS_VALIDOS.join(' | ')}`);
    process.exit(1);
  }
  if (estadoOrigen === estadoDestino) {
    console.error(`❌ El estado origen y destino no pueden ser iguales`);
    process.exit(1);
  }

  console.log(`\n🔄 Cambiando pedidos: "${estadoOrigen}" → "${estadoDestino}"`);
  console.log(`📦 Límite: ${limite === 999 ? 'todos' : limite} pedidos\n`);

  const snapshot = await db.collection('pedido')
    .where('estado', '==', estadoOrigen)
    .orderBy('fechaPedido', 'desc')
    .limit(limite)
    .get();

  if (snapshot.empty) {
    console.log(`⚠️  No hay pedidos en estado "${estadoOrigen}"`);
    process.exit(0);
  }

  console.log(`📋 Encontrados: ${snapshot.docs.length} pedidos en "${estadoOrigen}"\n`);

  let exitosos = 0;
  let errores  = 0;

  for (const doc of snapshot.docs) {
    try {
      await cambiarEstado(doc, estadoDestino);
      exitosos++;
      const pedido = doc.data();
      process.stdout.write(
        `\r✅ ${exitosos}/${snapshot.docs.length} — ${pedido.numeroPedido ?? doc.id} | ${pedido.nombreCliente}`
      );
    } catch (e) {
      errores++;
      console.error(`\n❌ Error en ${doc.id}:`, e.message);
    }
  }

  console.log(`\n\n📊 RESUMEN:`);
  console.log(`   ✅ Actualizados: ${exitosos}`);
  console.log(`   ❌ Errores:      ${errores}`);
  console.log(`   🔄 Transición:   ${estadoOrigen} → ${estadoDestino}\n`);
  process.exit(0);
}

main();