const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Evitar inicializar dos veces si ejecutas en entornos de prueba
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'el-gran-molino-6642d',
    });
}

const db = admin.firestore();

// 1. IMPORTAMOS TUS 100 PRODUCTOS REALES (Resumen de tu Script 3)
const MIS_100_PRODUCTOS = [
    { nombre: 'Pollo entero fresco', precio: 25000 }, { nombre: 'Pechuga de pollo kg', precio: 18000 },
    { nombre: 'Carne molida kg', precio: 35000 }, { nombre: 'Arroz 5kg', precio: 18000 },
    { nombre: 'Aceite girasol 3L', precio: 22000 }, { nombre: 'Huevos AA x30', precio: 16000 },
    // ... El script elegirá de tu lista completa de 100 productos
];

const CLIENTES = [
    'María García', 'Carlos López', 'Ana Martínez', 'Juan Rodríguez', 
    'Laura Sánchez', 'Pedro Gómez', 'Sofía Torres', 'Diego Ramírez'
];

const ESTADOS = ['pendiente', 'confirmado', 'entregado', 'cancelado'];

// Función para obtener productos aleatorios de tu lista de 100
function obtenerItemsAleatorios() {
    const cantidad = Math.floor(Math.random() * 4) + 1; // Pedidos de 1 a 4 productos
    // Aquí simulamos la selección de tus 100 productos
    return Array.from({ length: cantidad }, () => {
        const p = MIS_100_PRODUCTOS[Math.floor(Math.random() * MIS_100_PRODUCTOS.length)];
        return {
            nombre: p.nombre,
            precio: p.precio,
            cantidad: Math.floor(Math.random() * 3) + 1
        };
    });
}

async function crearPedido(i) {
    const items = obtenerItemsAleatorios();
    const total = items.reduce((acc, item) => acc + (item.precio * item.cantidad), 0);
    const cliente = CLIENTES[Math.floor(Math.random() * CLIENTES.length)];
    
    const pedidoRef = db.collection('pedido').doc();
    
    await pedidoRef.set({
        numeroPedido: `PED-100-${String(i + 1).padStart(3, '0')}`,
        nombreCliente: cliente,
        items: items,
        total: total,
        estado: ESTADOS[Math.floor(Math.random() * ESTADOS.length)],
        fechaCreacion: admin.firestore.Timestamp.now(),
        _esDatosDePrueba: true // Importante para borrarlos luego
    });
}

async function ejecutar() {
    const TOTAL = 100; // <--- AQUÍ DEFINIMOS LOS 100 PEDIDOS
    console.log(`\n🛒 Generando ${TOTAL} pedidos usando tus 100 productos...\n`);

    for (let i = 0; i < TOTAL; i++) {
        await crearPedido(i);
        process.stdout.write(`\r✅ Pedido ${i + 1}/100 creado`);
    }

    console.log('\n\n✨ ¡Proceso terminado! Ya tienes 100 pedidos en Firebase.');
    process.exit(0);
}

ejecutar();