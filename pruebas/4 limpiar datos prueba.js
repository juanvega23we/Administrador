// ============================================================
//  SCRIPT 4 — Limpiar todos los datos de prueba
//  Granero del Norte | el-gran-molino-6642d
// ============================================================
//
//  Borra ÚNICAMENTE los documentos marcados con:
//    _esDatosDePrueba: true
//
//  Colecciones que limpia: pedido, detalle_pedido, venta, productos
//
//  USO:
//    node 4_limpiar_datos_prueba.js
// ============================================================

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const readline = require('readline');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'el-gran-molino-6642d',
});

const db = admin.firestore();

const COLECCIONES = ['pedido', 'detalle_pedido', 'venta', 'productos'];

async function contarDocumentosPrueba() {
  const conteos = {};
  for (const col of COLECCIONES) {
    const snap = await db.collection(col)
      .where('_esDatosDePrueba', '==', true)
      .get();
    conteos[col] = snap.size;
  }
  return conteos;
}

async function borrarColeccion(coleccion) {
  const snap = await db.collection(coleccion)
    .where('_esDatosDePrueba', '==', true)
    .get();

  if (snap.empty) return 0;

  // Borrar en batches de 500 (límite de Firestore)
  let borrados = 0;
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 500) {
    chunks.push(snap.docs.slice(i, i + 500));
  }

  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    borrados += chunk.length;
  }

  return borrados;
}

function pregunta(texto) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise(resolve => {
    rl.question(texto, answer => {
      rl.close();
      resolve(answer.trim().toLowerCase());
    });
  });
}

async function main() {
  console.log(`\n🔍 Buscando datos de prueba en Firestore...\n`);

  const conteos = await contarDocumentosPrueba();
  const total   = Object.values(conteos).reduce((s, n) => s + n, 0);

  if (total === 0) {
    console.log(`✅ No hay datos de prueba que borrar. La base está limpia.\n`);
    process.exit(0);
  }

  console.log(`📋 Documentos de prueba encontrados:`);
  for (const [col, count] of Object.entries(conteos)) {
    if (count > 0) console.log(`   • ${col}: ${count} documentos`);
  }
  console.log(`   ─────────────────────────`);
  console.log(`   Total: ${total} documentos\n`);

  const respuesta = await pregunta(`⚠️  ¿Confirmas que quieres borrar estos ${total} documentos? (si/no): `);

  if (respuesta !== 'si' && respuesta !== 's') {
    console.log(`\n❌ Operación cancelada. No se borró nada.\n`);
    process.exit(0);
  }

  console.log(`\n🗑️  Borrando datos de prueba...\n`);

  let totalBorrados = 0;
  for (const col of COLECCIONES) {
    if (conteos[col] === 0) continue;
    const borrados = await borrarColeccion(col);
    totalBorrados += borrados;
    console.log(`   ✅ ${col}: ${borrados} documentos borrados`);
  }

  console.log(`\n🎉 Limpieza completada: ${totalBorrados} documentos eliminados`);
  console.log(`   Solo se borraron documentos con _esDatosDePrueba: true\n`);
  process.exit(0);
}

main();