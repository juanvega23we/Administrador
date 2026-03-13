// ============================================================
//  SCRIPT 3 — Crear productos de prueba
//  Granero del Norte | el-gran-molino-6642d
// ============================================================
//
//  USO:
//    node 3_crear_productos.js        → crea 30 productos de prueba
//    node 3_crear_productos.js 50     → crea 50 productos
//
//  Crea productos con estructura idéntica a la de tu Firestore:
//  activo, categoria, codigo, creadoPor, fechaCreacion,
//  imagen, nombre, precio, stock, subtexto
// ============================================================

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'el-gran-molino-6642d',
});

const db = admin.firestore();

// Productos realistas para un granero/tienda de abarrotes
const PRODUCTOS_BASE = [
  // ── Carnes (prefijo 22) ──────────────────────────────────
  { nombre: 'Pollo entero fresco',         categoria: 'Carnes',   precio: 25000, subtexto: 'Por unidad aprox 2kg',         stock: 20, prefijo: '22' },
  { nombre: 'Pechuga de pollo kg',         categoria: 'Carnes',   precio: 18000, subtexto: 'Precio por kilogramo',         stock: 15, prefijo: '22' },
  { nombre: 'Muslo de pollo kg',           categoria: 'Carnes',   precio: 14000, subtexto: 'Con hueso',                    stock: 18, prefijo: '22' },
  { nombre: 'Ala de pollo kg',             categoria: 'Carnes',   precio: 12000, subtexto: 'Ideal para asado',             stock: 22, prefijo: '22' },
  { nombre: 'Carne molida de res kg',      categoria: 'Carnes',   precio: 35000, subtexto: 'Res primera calidad',          stock: 10, prefijo: '22' },
  { nombre: 'Lomo de res kg',              categoria: 'Carnes',   precio: 45000, subtexto: 'Corte especial',               stock: 5,  prefijo: '22' },
  { nombre: 'Costilla de res kg',          categoria: 'Carnes',   precio: 32000, subtexto: 'Para sancocho',                stock: 8,  prefijo: '22' },
  { nombre: 'Solomo de res kg',            categoria: 'Carnes',   precio: 48000, subtexto: 'Corte fino',                   stock: 6,  prefijo: '22' },
  { nombre: 'Costilla de cerdo kg',        categoria: 'Carnes',   precio: 28000, subtexto: 'Ideal para asado',             stock: 12, prefijo: '22' },
  { nombre: 'Chuleta de cerdo kg',         categoria: 'Carnes',   precio: 32000, subtexto: 'Precio por kilogramo',         stock: 10, prefijo: '22' },
  { nombre: 'Lomo de cerdo kg',            categoria: 'Carnes',   precio: 38000, subtexto: 'Magro y tierno',               stock: 8,  prefijo: '22' },
  { nombre: 'Tocino ahumado 500g',         categoria: 'Carnes',   precio: 18000, subtexto: 'Listo para freír',             stock: 15, prefijo: '22' },
  { nombre: 'Salchicha x10',               categoria: 'Carnes',   precio: 12000, subtexto: 'Salchicha de res y cerdo',     stock: 25, prefijo: '22' },
  { nombre: 'Chorizo santarrosano x6',     categoria: 'Carnes',   precio: 15000, subtexto: 'Artesanal',                    stock: 20, prefijo: '22' },

  // ── Granos (prefijo 33) ──────────────────────────────────
  { nombre: 'Arroz blanco 5kg',            categoria: 'Granos',   precio: 18000, subtexto: 'Arroz de grano largo',         stock: 50, prefijo: '33' },
  { nombre: 'Arroz blanco 10kg',           categoria: 'Granos',   precio: 34000, subtexto: 'Económico familiar',           stock: 30, prefijo: '33' },
  { nombre: 'Arroz integral 2kg',          categoria: 'Granos',   precio: 12000, subtexto: 'Rico en fibra',                stock: 28, prefijo: '33' },
  { nombre: 'Frijol negro 1kg',            categoria: 'Granos',   precio: 8500,  subtexto: 'Frijol seco calidad extra',    stock: 40, prefijo: '33' },
  { nombre: 'Frijol rojo 1kg',             categoria: 'Granos',   precio: 9000,  subtexto: 'Para sopas y guisos',          stock: 35, prefijo: '33' },
  { nombre: 'Frijol bola roja 1kg',        categoria: 'Granos',   precio: 9500,  subtexto: 'Típico colombiano',            stock: 32, prefijo: '33' },
  { nombre: 'Lenteja 500g',                categoria: 'Granos',   precio: 6000,  subtexto: 'Legumbre nutritiva',           stock: 35, prefijo: '33' },
  { nombre: 'Garbanzo 500g',               categoria: 'Granos',   precio: 7500,  subtexto: 'Importado',                    stock: 25, prefijo: '33' },
  { nombre: 'Arveja 500g',                 categoria: 'Granos',   precio: 5500,  subtexto: 'Seca lista para cocinar',      stock: 28, prefijo: '33' },
  { nombre: 'Maíz pira 500g',              categoria: 'Granos',   precio: 9000,  subtexto: 'Para crispetas y cocinar',     stock: 20, prefijo: '33' },
  { nombre: 'Maíz trillado 1kg',           categoria: 'Granos',   precio: 7000,  subtexto: 'Para arepas y mazamorra',      stock: 25, prefijo: '33' },
  { nombre: 'Quinoa 500g',                 categoria: 'Granos',   precio: 14000, subtexto: 'Superalimento andino',         stock: 18, prefijo: '33' },

  // ── Despensa (prefijo 44) ────────────────────────────────
  { nombre: 'Aceite girasol 3L',           categoria: 'Despensa', precio: 22000, subtexto: 'Bajo en colesterol',           stock: 30, prefijo: '44' },
  { nombre: 'Aceite girasol 1L',           categoria: 'Despensa', precio: 9000,  subtexto: 'Presentación pequeña',         stock: 40, prefijo: '44' },
  { nombre: 'Aceite de oliva 500ml',       categoria: 'Despensa', precio: 35000, subtexto: 'Extra virgen importado',       stock: 15, prefijo: '44' },
  { nombre: 'Aceite de maíz 3L',           categoria: 'Despensa', precio: 20000, subtexto: 'Para freír y cocinar',         stock: 25, prefijo: '44' },
  { nombre: 'Azúcar blanca 2kg',           categoria: 'Despensa', precio: 9000,  subtexto: 'Azúcar refinada',             stock: 45, prefijo: '44' },
  { nombre: 'Azúcar morena 1kg',           categoria: 'Despensa', precio: 6500,  subtexto: 'Sin refinar',                 stock: 30, prefijo: '44' },
  { nombre: 'Panela redonda',              categoria: 'Despensa', precio: 4500,  subtexto: 'Dulce natural de caña',        stock: 60, prefijo: '44' },
  { nombre: 'Panela pulverizada 500g',     categoria: 'Despensa', precio: 5000,  subtexto: 'Lista para disolver',          stock: 40, prefijo: '44' },
  { nombre: 'Sal refinada 1kg',            categoria: 'Despensa', precio: 3500,  subtexto: 'Con yodo y flúor',            stock: 50, prefijo: '44' },
  { nombre: 'Sal gruesa 1kg',              categoria: 'Despensa', precio: 3000,  subtexto: 'Para conservas',               stock: 35, prefijo: '44' },
  { nombre: 'Pasta espagueti 500g',        categoria: 'Despensa', precio: 5500,  subtexto: 'Trigo duro importado',         stock: 40, prefijo: '44' },
  { nombre: 'Pasta tornillo 500g',         categoria: 'Despensa', precio: 5500,  subtexto: 'Variedad de pasta',           stock: 38, prefijo: '44' },
  { nombre: 'Pasta penne 500g',            categoria: 'Despensa', precio: 5500,  subtexto: 'Ideal para hornear',           stock: 36, prefijo: '44' },
  { nombre: 'Harina de trigo 1kg',         categoria: 'Despensa', precio: 6000,  subtexto: 'Todo uso',                    stock: 35, prefijo: '44' },
  { nombre: 'Harina de maíz 1kg',          categoria: 'Despensa', precio: 5500,  subtexto: 'Para arepas',                  stock: 40, prefijo: '44' },
  { nombre: 'Café molido 250g',            categoria: 'Despensa', precio: 12000, subtexto: 'Tostado medio',                stock: 25, prefijo: '44' },
  { nombre: 'Café molido 500g',            categoria: 'Despensa', precio: 22000, subtexto: 'Tostado fuerte',               stock: 20, prefijo: '44' },
  { nombre: 'Café instantáneo 170g',       categoria: 'Despensa', precio: 16000, subtexto: 'Listo en segundos',            stock: 22, prefijo: '44' },
  { nombre: 'Chocolate en polvo 250g',     categoria: 'Despensa', precio: 9500,  subtexto: 'Para taza caliente',           stock: 28, prefijo: '44' },
  { nombre: 'Atún en lata x3',             categoria: 'Despensa', precio: 14000, subtexto: 'En agua o aceite',             stock: 35, prefijo: '44' },
  { nombre: 'Sardinas en lata x2',         categoria: 'Despensa', precio: 8000,  subtexto: 'En salsa de tomate',           stock: 30, prefijo: '44' },
  { nombre: 'Salsa de tomate 400g',        categoria: 'Despensa', precio: 7000,  subtexto: 'Para pasta y pizza',           stock: 32, prefijo: '44' },
  { nombre: 'Mayonesa 400g',               categoria: 'Despensa', precio: 8500,  subtexto: 'Receta original',              stock: 28, prefijo: '44' },
  { nombre: 'Mostaza 200g',                categoria: 'Despensa', precio: 5000,  subtexto: 'Amarilla clásica',             stock: 25, prefijo: '44' },
  { nombre: 'Vinagre blanco 1L',           categoria: 'Despensa', precio: 4500,  subtexto: 'Para ensaladas y conservas',   stock: 20, prefijo: '44' },

  // ── Lácteos (prefijo 55) ─────────────────────────────────
  { nombre: 'Leche entera 1L',             categoria: 'Lácteos',  precio: 4200,  subtexto: 'Leche pasteurizada',           stock: 40, prefijo: '55' },
  { nombre: 'Leche descremada 1L',         categoria: 'Lácteos',  precio: 4500,  subtexto: 'Baja en grasa',               stock: 30, prefijo: '55' },
  { nombre: 'Leche en polvo 400g',         categoria: 'Lácteos',  precio: 18000, subtexto: 'Entera instantánea',          stock: 22, prefijo: '55' },
  { nombre: 'Queso campesino 500g',        categoria: 'Lácteos',  precio: 14000, subtexto: 'Fresco artesanal',             stock: 20, prefijo: '55' },
  { nombre: 'Queso mozzarella 500g',       categoria: 'Lácteos',  precio: 18000, subtexto: 'Para pizza y gratinar',        stock: 15, prefijo: '55' },
  { nombre: 'Queso doble crema 250g',      categoria: 'Lácteos',  precio: 10000, subtexto: 'Suave y cremoso',             stock: 18, prefijo: '55' },
  { nombre: 'Mantequilla 250g',            categoria: 'Lácteos',  precio: 9500,  subtexto: 'Con sal',                     stock: 18, prefijo: '55' },
  { nombre: 'Mantequilla 500g',            categoria: 'Lácteos',  precio: 17000, subtexto: 'Sin sal',                     stock: 14, prefijo: '55' },
  { nombre: 'Yogur natural 1L',            categoria: 'Lácteos',  precio: 8000,  subtexto: 'Sin azúcar añadida',          stock: 15, prefijo: '55' },
  { nombre: 'Yogur fresa 200g',            categoria: 'Lácteos',  precio: 3500,  subtexto: 'Con fruta real',               stock: 25, prefijo: '55' },
  { nombre: 'Crema de leche 200ml',        categoria: 'Lácteos',  precio: 6500,  subtexto: 'Para cocinar y repostería',    stock: 20, prefijo: '55' },
  { nombre: 'Kumis 1L',                    categoria: 'Lácteos',  precio: 7500,  subtexto: 'Bebida láctea fermentada',     stock: 16, prefijo: '55' },

  // ── Verduras (prefijo 66) ────────────────────────────────
  { nombre: 'Papa pastusa 5kg',            categoria: 'Verduras', precio: 12000, subtexto: 'Papa de primera',              stock: 30, prefijo: '66' },
  { nombre: 'Papa criolla 2kg',            categoria: 'Verduras', precio: 8000,  subtexto: 'Para ajiaco y sopas',          stock: 25, prefijo: '66' },
  { nombre: 'Papa sabanera 5kg',           categoria: 'Verduras', precio: 11000, subtexto: 'Para hervir y freír',          stock: 22, prefijo: '66' },
  { nombre: 'Cebolla cabezona 2kg',        categoria: 'Verduras', precio: 7000,  subtexto: 'Fresca del día',               stock: 25, prefijo: '66' },
  { nombre: 'Cebolla larga x manojo',      categoria: 'Verduras', precio: 3500,  subtexto: 'Para sofritos',                stock: 30, prefijo: '66' },
  { nombre: 'Zanahoria 1kg',               categoria: 'Verduras', precio: 4500,  subtexto: 'Lavada y seleccionada',        stock: 22, prefijo: '66' },
  { nombre: 'Tomate chonto 1kg',           categoria: 'Verduras', precio: 6000,  subtexto: 'Maduro para cocinar',          stock: 20, prefijo: '66' },
  { nombre: 'Tomate cherry 250g',          categoria: 'Verduras', precio: 5500,  subtexto: 'Para ensaladas',               stock: 15, prefijo: '66' },
  { nombre: 'Ajo cabeza x5',               categoria: 'Verduras', precio: 4000,  subtexto: 'Ajo fresco nacional',          stock: 28, prefijo: '66' },
  { nombre: 'Pimentón rojo grande',        categoria: 'Verduras', precio: 3500,  subtexto: 'Por unidad',                   stock: 20, prefijo: '66' },
  { nombre: 'Pepino cohombro x2',          categoria: 'Verduras', precio: 3000,  subtexto: 'Frescos del día',              stock: 18, prefijo: '66' },
  { nombre: 'Aguacate hass x3',            categoria: 'Verduras', precio: 9000,  subtexto: 'Maduros listos',               stock: 15, prefijo: '66' },
  { nombre: 'Plátano maduro x5',           categoria: 'Verduras', precio: 5000,  subtexto: 'Para fritar',                  stock: 25, prefijo: '66' },
  { nombre: 'Plátano verde x5',            categoria: 'Verduras', precio: 4500,  subtexto: 'Para patacones y cocinar',     stock: 22, prefijo: '66' },

  // ── Aseo (prefijo 77) ────────────────────────────────────
  { nombre: 'Jabón de ropa 2kg',           categoria: 'Aseo',     precio: 14000, subtexto: 'Para ropa blanca y color',     stock: 20, prefijo: '77' },
  { nombre: 'Detergente líquido 1L',       categoria: 'Aseo',     precio: 12000, subtexto: 'Para lavadora y a mano',       stock: 18, prefijo: '77' },
  { nombre: 'Jabón de baño x3',            categoria: 'Aseo',     precio: 7500,  subtexto: 'Antibacterial',                stock: 25, prefijo: '77' },
  { nombre: 'Shampoo 400ml',               categoria: 'Aseo',     precio: 16000, subtexto: 'Para todo tipo de cabello',    stock: 15, prefijo: '77' },
  { nombre: 'Pasta dental 75ml',           categoria: 'Aseo',     precio: 6500,  subtexto: 'Con flúor',                   stock: 22, prefijo: '77' },
  { nombre: 'Papel higiénico x4',          categoria: 'Aseo',     precio: 9000,  subtexto: 'Doble hoja suave',             stock: 30, prefijo: '77' },
  { nombre: 'Papel higiénico x12',         categoria: 'Aseo',     precio: 24000, subtexto: 'Paquete familiar',             stock: 20, prefijo: '77' },
  { nombre: 'Desinfectante 1L',            categoria: 'Aseo',     precio: 8000,  subtexto: 'Para pisos y superficies',     stock: 18, prefijo: '77' },
  { nombre: 'Limpiavidrios 500ml',         categoria: 'Aseo',     precio: 7000,  subtexto: 'Sin rayas',                   stock: 15, prefijo: '77' },
  { nombre: 'Esponja x3',                  categoria: 'Aseo',     precio: 5500,  subtexto: 'Doble cara',                   stock: 25, prefijo: '77' },

  // ── Bebidas (prefijo 88) ─────────────────────────────────
  { nombre: 'Agua botella 600ml',          categoria: 'Bebidas',  precio: 2500,  subtexto: 'Agua purificada',              stock: 60, prefijo: '88' },
  { nombre: 'Agua botella 1.5L',           categoria: 'Bebidas',  precio: 4000,  subtexto: 'Agua purificada',              stock: 50, prefijo: '88' },
  { nombre: 'Jugo de naranja 1L',          categoria: 'Bebidas',  precio: 7500,  subtexto: 'Natural pasteurizado',         stock: 25, prefijo: '88' },
  { nombre: 'Jugo de mango 1L',            categoria: 'Bebidas',  precio: 7000,  subtexto: 'Tropical natural',             stock: 22, prefijo: '88' },
  { nombre: 'Gaseosa cola 2L',             categoria: 'Bebidas',  precio: 8000,  subtexto: 'Refresco familiar',            stock: 30, prefijo: '88' },
  { nombre: 'Gaseosa limón 1.5L',          categoria: 'Bebidas',  precio: 6500,  subtexto: 'Sabor cítrico',                stock: 28, prefijo: '88' },
  { nombre: 'Té frío limón 500ml',         categoria: 'Bebidas',  precio: 4500,  subtexto: 'Refrescante y natural',        stock: 20, prefijo: '88' },
  { nombre: 'Bebida energizante 250ml',    categoria: 'Bebidas',  precio: 5500,  subtexto: 'Con taurina y cafeína',        stock: 18, prefijo: '88' },
  // ── Adicionales para completar 100 ────────────────────────
  { nombre: 'Huevos AA x30',           categoria: 'Lácteos',  precio: 16000, subtexto: 'Panal completo frescura',    stock: 25, prefijo: '55' },
  { nombre: 'Huevos A x15',            categoria: 'Lácteos',  precio: 8500,  subtexto: 'Media cubeta',               stock: 30, prefijo: '55' },
  { nombre: 'Pan tajado familiar',     categoria: 'Despensa', precio: 7500,  subtexto: 'Blanco 500g',                stock: 20, prefijo: '44' },
  { nombre: 'Tostadas integrales',     categoria: 'Despensa', precio: 5000,  subtexto: 'Paquete x12',                stock: 25, prefijo: '44' },
  { nombre: 'Mermelada de fresa',      categoria: 'Despensa', precio: 6500,  subtexto: 'Frasco vidrio 250g',         stock: 15, prefijo: '44' },
];

function generarCodigo(prefijo, index) {
  return `${prefijo}${String(index + 1).padStart(4, '0')}`;
}

async function crearProducto(prod, index) {
  const ref = db.collection('productos').doc();
  await ref.set({
    activo:             true,
    categoria:          prod.categoria,
    codigo:             generarCodigo(prod.prefijo, index),
    creadoPor:          'script_prueba',
    fechaCreacion:      admin.firestore.FieldValue.serverTimestamp(),
    fechaActualizacion: admin.firestore.FieldValue.serverTimestamp(),
    imagen:             '',
    nombre:             prod.nombre,
    precio:             prod.precio,
    stock:              prod.stock,
    subtexto:           prod.subtexto,
    _esDatosDePrueba:   true,
  });
  return { id: ref.id, nombre: prod.nombre };
}

async function main() {
  const cantidad = Math.min(parseInt(process.argv[2]) || 30, PRODUCTOS_BASE.length);

  console.log(`\n🛒 Creando ${cantidad} productos de prueba...\n`);

  const productosACrear = PRODUCTOS_BASE.slice(0, cantidad);
  let creados = 0;
  let errores = 0;

  for (let i = 0; i < productosACrear.length; i++) {
    try {
      const r = await crearProducto(productosACrear[i], i);
      creados++;
      process.stdout.write(`\r✅ ${creados}/${productosACrear.length} — ${r.nombre}`);
    } catch (e) {
      errores++;
      console.error(`\n❌ Error:`, e.message);
    }
  }

  console.log(`\n\n📊 RESUMEN:`);
  console.log(`   ✅ Creados: ${creados} productos`);
  console.log(`   ❌ Errores: ${errores}`);
  console.log(`\n💡 Para borrarlos después: node 4_limpiar_datos_prueba.js\n`);
  process.exit(0);
}

main();