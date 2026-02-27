const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Escucha cambios en la colección 'pedido'.
 * - Estado cambia a 'confirmado' → descuenta stock
 * - Estado cambia a 'cancelado' (venía de confirmado) → devuelve stock
 */
exports.onPedidoUpdated = functions.firestore
  .document("pedido/{pedidoId}")
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const despues = change.after.data();

    const estadoAntes = antes.estado;
    const estadoDespues = despues.estado;

    // Solo actuar si el estado cambió
    if (estadoAntes === estadoDespues) return null;

    const pedidoId = context.params.pedidoId;
    const idPedido = despues.idPedido || pedidoId;

    // Confirmar → descontar stock
    if (estadoDespues === "confirmado" && estadoAntes === "pendiente") {
      console.log(`[STOCK] Descontando stock para pedido: ${pedidoId}`);
      await ajustarStock(idPedido, pedidoId, -1);
    }

    // Cancelar desde confirmado → devolver stock
    if (estadoDespues === "cancelado" && estadoAntes === "confirmado") {
      console.log(`[STOCK] Devolviendo stock para pedido: ${pedidoId}`);
      await ajustarStock(idPedido, pedidoId, +1);
    }

    return null;
  });

/**
 * Ajusta el stock de cada producto del pedido.
 * @param {string} idPedido - ID lógico del pedido
 * @param {string} pedidoId - ID del documento Firestore
 * @param {number} signo    - -1 descontar, +1 devolver
 */
async function ajustarStock(idPedido, pedidoId, signo) {
  let items = [];

  // Buscar en detalle_pedido por idPedido (campo lógico)
  let detallesSnap = await db
    .collection("detalle_pedido")
    .where("idPedido", "==", idPedido)
    .get();

  // Si no encontró, intentar con el docId directamente
  if (detallesSnap.empty) {
    detallesSnap = await db
      .collection("detalle_pedido")
      .where("idPedido", "==", pedidoId)
      .get();
  }

  if (!detallesSnap.empty) {
    items = detallesSnap.docs.map((d) => d.data());
  } else {
    // Fallback: array 'items' dentro del documento pedido (formato viejo)
    const pedidoDoc = await db.collection("pedido").doc(pedidoId).get();
    const pedidoData = pedidoDoc.data();
    items = pedidoData && pedidoData.items ? pedidoData.items : [];
  }

  if (items.length === 0) {
    console.warn(`[STOCK] No se encontraron productos para pedido: ${pedidoId}`);
    return;
  }

  // Transacción atómica — todos o ninguno
  await db.runTransaction(async (transaction) => {
    const refs = [];

    for (const item of items) {
      const idProducto = item.idProducto || item.id || null;
      const cantidad = item.cantidad || 0;

      if (!idProducto || cantidad <= 0) {
        console.warn("[STOCK] Item inválido:", item);
        continue;
      }

      refs.push({
        ref: db.collection("productos").doc(String(idProducto)),
        cantidad: cantidad,
      });
    }

    // Leer todos primero (requerido por Firestore)
    const snapshots = await Promise.all(
      refs.map((r) => transaction.get(r.ref))
    );

    for (let i = 0; i < refs.length; i++) {
      const snap = snapshots[i];
      const { ref, cantidad } = refs[i];

      if (!snap.exists) {
        console.warn(`[STOCK] Producto no encontrado: ${ref.id}`);
        continue;
      }

      const stockActual = snap.data().stock || 0;
      const nuevoStock = Math.max(0, stockActual + signo * cantidad);

      console.log(
        `[STOCK] Producto ${ref.id}: ${stockActual} → ${nuevoStock}`
      );

      transaction.update(ref, {
        stock: nuevoStock,
        ultimaActualizacionStock: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}