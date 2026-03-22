// ============================================================
//  SCRIPT — Crear 100 pedidos usando productos REALES
//  Granero del Norte | el-gran-molino-6642d
//
//  USO:
//    node crear_pedidos_reales.js        → crea 100 pedidos
//    node crear_pedidos_reales.js 50     → crea 50 pedidos
// ============================================================

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'el-gran-molino-6642d',
  });
}

const db = admin.firestore();

const CLIENTES = [
  { id: 'cliente_test_01', nombre: 'María García',    telefono: '3001234567', direccion: 'Calle 45 #12-34, El Centro' },
  { id: 'cliente_test_02', nombre: 'Carlos López',    telefono: '3112345678', direccion: 'Carrera 7 #89-10, Chapinero' },
  { id: 'cliente_test_03', nombre: 'Ana Martínez',    telefono: '3223456789', direccion: 'Avenida 68 #23-56, Kennedy' },
  { id: 'cliente_test_04', nombre: 'Juan Rodríguez',  telefono: '3134567890', direccion: 'Calle 100 #15-20, Usaquén' },
  { id: 'cliente_test_05', nombre: 'Laura Sánchez',   telefono: '3045678901', direccion: 'Transversal 50 #30-40, Suba' },
  { id: 'cliente_test_06', nombre: 'Pedro Gómez',     telefono: '3156789012', direccion: 'Calle 80 #20-15, Engativá' },
  { id: 'cliente_test_07', nombre: 'Sofía Torres',    telefono: '3067890123', direccion: 'Carrera 30 #45-67, Fontibón' },
  { id: 'cliente_test_08', nombre: 'Diego Ramírez',   telefono: '3178901234', direccion: 'Avenida 1 #50-30, Bosa' },
];

const METODOS_PAGO = ['efectivo', 'efectivo', 'transferencia', 'efectivo'];

// Distribución realista de estados
// confirmado incluye bajada de stock (igual que tu app)
const ESTADOS_CONFIG = [
  { estado: 'pendiente',   peso: 30 },
  { estado: 'confirmado',  peso: 35 },
  { estado: 'entregado',   peso: 25 },
  { estado: 'cancelado',   peso: 10 },
];

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickEstado() {
  const total = ESTADOS_CONFIG.reduce((s, e) => s + e.peso, 0);
  let rand = Math.random() * total;
  for (const e of ESTADOS_CONFIG) {
    rand -= e.peso;
    if (rand <= 0) return e.estado;
  }
  return 'pendiente';
}

function randomFecha() {
  const d = new Date();

  d.setHours(Math.floor(Math.random() * 14) + 7); // entre 7am y 9pm
  d.setMinutes(Math.floor(Math.random() * 60));
  return admin.firestore.Timestamp.fromDate(d);
}

async function generarNumeroPedido() {
  const ref = db.collection('config').doc('contadorPedidos');
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const nuevo = ((snap.data()?.ultimo ?? 0)) + 1;
    tx.set(ref, { ultimo: nuevo }, { merge: true });
    const fecha = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    return `PED-${fecha}-${String(nuevo).padStart(4, '0')}`;
  });
}

async function generarNumeroVenta() {
  const ref = db.collection('config').doc('contadorVentas');
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const nuevo = ((snap.data()?.ultimo ?? 0)) + 1;
    tx.set(ref, { ultimo: nuevo }, { merge: true });
    const fecha = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    return `VEN-${fecha}-${String(nuevo).padStart(4, '0')}`;
  });
}

// Selecciona entre 1 y 4 productos aleatorios del catálogo real
function seleccionarItems(productosReales) {
  const cantidad = Math.floor(Math.random() * 4) + 1;
  const shuffled = [...productosReales].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, cantidad).map(p => ({
    idProducto:     p.id,
    nombre:         p.nombre,
    precio:         p.precio,
    imagen:         p.imagen ?? '',
    cantidad:       Math.floor(Math.random() * 3) + 1,
  }));
}

async function crearPedido(productosReales) {
  const cliente      = pick(CLIENTES);
  const estado       = pickEstado();
  const fecha        = randomFecha();
  const items        = seleccionarItems(productosReales);
  const metodoPago   = pick(METODOS_PAGO);
  const numeroPedido = await generarNumeroPedido();

  const subtotal = items.reduce((s, i) => s + i.precio * i.cantidad, 0);
  const total    = subtotal;

  const pedidoRef    = db.collection('pedido').doc();
  const idPedido     = pedidoRef.id;
  const detalleRefs  = items.map(() => db.collection('detalle_pedido').doc());
  const idsDetalles  = detalleRefs.map(r => r.id);

  const batch = db.batch();

  // ── Pedido ───────────────────────────────────────────────
  batch.set(pedidoRef, {
    idPedido,
    numeroPedido,
    idCliente:            cliente.id,
    nombreCliente:        cliente.nombre,
    telefonoContacto:     cliente.telefono,
    direccionEntrega:     cliente.direccion,
    fechaPedido:          fecha,
    fechaCreacion:        fecha,
    fechaActualizacion:   fecha,
    fechaEstimadaEntrega: admin.firestore.Timestamp.fromDate(
      new Date(fecha.toDate().getTime() + 86400000)
    ),
    estado,
    estadoAnterior:   null,
    historialEstados: [{ estado, fecha, cambiadoPor: 'script_prueba' }],
    subtotal,
    descuento:        0,
    total,
    totalArticulos:   items.reduce((s, i) => s + i.cantidad, 0),
    idsDetalles,
    cantidadDetalles: idsDetalles.length,
    metodoPago,
    observaciones:    '',
    actualizado_por:  'script_prueba',
    cancelado:        estado === 'cancelado',
    año:              fecha.toDate().getFullYear(),
    mes:              fecha.toDate().getMonth() + 1,
    dia:              fecha.toDate().getDate(),
    diaSemana:        fecha.toDate().getDay(),
    _esDatosDePrueba: true,
  });

  // ── Detalles ─────────────────────────────────────────────
  items.forEach((item, i) => {
    batch.set(detalleRefs[i], {
      idDetalle:      idsDetalles[i],
      idPedido,
      numeroPedido,
      idProducto:     item.idProducto,
      nombreProducto: item.nombre,
      cantidad:       item.cantidad,
      precioUnitario: item.precio,
      subtotal:       item.precio * item.cantidad,
      imagen:         item.imagen,
      fechaRegistro:  fecha,
      _esDatosDePrueba: true,
    });
  });

  // ── Si confirmado → bajar stock (igual que tu app) ───────
  if (estado === 'confirmado') {
    items.forEach(item => {
      const prodRef = db.collection('productos').doc(item.idProducto);
      batch.update(prodRef, {
        stock: admin.firestore.FieldValue.increment(-item.cantidad),
      });
    });
  }

  // ── Si entregado → crear venta ───────────────────────────
  if (estado === 'entregado') {
    const ventaRef    = db.collection('venta').doc();
    const numeroVenta = await generarNumeroVenta();
    batch.set(ventaRef, {
      idVenta:       ventaRef.id,
      numeroVenta,
      idPedido,
      numeroPedido,
      idCliente:     cliente.id,
      nombreCliente: cliente.nombre,
      fechaVenta:    fecha,
      total,
      registradoPor: 'script_prueba',
      año:           fecha.toDate().getFullYear(),
      mes:           fecha.toDate().getMonth() + 1,
      dia:           fecha.toDate().getDate(),
      _esDatosDePrueba: true,
    });
  }

  await batch.commit();
  return { numeroPedido, estado, total, cliente: cliente.nombre };
}

async function main() {
  const cantidad = parseInt(process.argv[2]) || 100;

  console.log(`\n🔍 Leyendo productos reales de Firestore...`);

  // Leer SOLO productos activos reales (no de prueba)
  const snapProductos = await db.collection('productos')
    .where('activo', '==', true)
    
    .get();

  if (snapProductos.empty) {
    console.error(`\n❌ No hay productos activos en Firestore.`);
    console.error(`   Agrega productos reales desde el panel antes de correr este script.\n`);
    process.exit(1);
  }

  const productosReales = snapProductos.docs
    .filter(d => !d.data()._esDatosDePrueba)
    .map(d => ({ id: d.id, ...d.data() }));
  console.log(`✅ ${productosReales.length} productos reales encontrados\n`);
  console.log(`🚀 Creando ${cantidad} pedidos de prueba...\n`);

  let creados = 0;
  let errores = 0;

  for (let i = 0; i < cantidad; i++) {
    try {
      const r = await crearPedido(productosReales);
      creados++;
      process.stdout.write(
        `\r✅ ${creados}/${cantidad} — ${r.numeroPedido} | ${r.estado} | $${r.total.toLocaleString('es-CO')} | ${r.cliente}`
      );
    } catch (e) {
      errores++;
      console.error(`\n❌ Error en pedido ${i + 1}:`, e.message);
    }
  }

  console.log(`\n\n📊 RESUMEN:`);
  console.log(`   ✅ Creados:  ${creados} pedidos`);
  console.log(`   ❌ Errores:  ${errores}`);
  console.log(`\n⚠️  El stock de los productos REALES fue modificado por los pedidos confirmados.`);
  console.log(`   Cuando termines las pruebas corre: node "4 limpiar datos prueba.js"`);
  console.log(`   Luego ajusta el stock manualmente desde el panel si es necesario.\n`);
  process.exit(0);
}

main();