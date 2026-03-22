const functions = require("firebase-functions");
const admin     = require("firebase-admin");
const ExcelJS   = require("exceljs");
const cors      = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

function getNumeroPedido(p) {
  return p.numeroPedido || p.idPedido || p.numero || p.id || p.codigo || '—';
}


//  FUNCIÓN 1: onPedidoUpdated

exports.onPedidoUpdated = functions.firestore
  .document("pedido/{pedidoId}")
  .onUpdate(async (change, context) => {
    const antes   = change.before.data();
    const despues = change.after.data();
    const estadoAntes   = antes?.estado;
    const estadoDespues = despues?.estado;

    if (!estadoAntes || !estadoDespues) return null;
    if (estadoAntes === estadoDespues) return null;

    const estadosValidos = ['pendiente', 'confirmado', 'despachado', 'entregado', 'cancelado'];
    if (!estadosValidos.includes(estadoAntes) || !estadosValidos.includes(estadoDespues)) return null;

    const pedidoId = context.params.pedidoId;
    const idPedido = despues.idPedido || pedidoId;

    if (estadoDespues === "confirmado" && estadoAntes === "pendiente") {
      await ajustarStock(idPedido, pedidoId, -1);
    }
    if (estadoDespues === "cancelado" && (estadoAntes === "confirmado" || estadoAntes === "despachado")) {
      await ajustarStock(idPedido, pedidoId, +1);
    }
    return null;
  });

async function ajustarStock(idPedido, pedidoId, signo) {
  let items = [];
  let detallesSnap = await db.collection("detalle_pedido").where("idPedido", "==", idPedido).get();
  if (detallesSnap.empty) {
    detallesSnap = await db.collection("detalle_pedido").where("idPedido", "==", pedidoId).get();
  }
  if (!detallesSnap.empty) {
    items = detallesSnap.docs
      .map((d) => d.data())
      .filter((item) => !item.omitido);
  } else {
    const pedidoDoc  = await db.collection("pedido").doc(pedidoId).get();
    const pedidoData = pedidoDoc.data();
    items = pedidoData && pedidoData.items ? pedidoData.items : [];
  }
  if (items.length === 0) return;

  await db.runTransaction(async (transaction) => {
    const refs = [];
    for (const item of items) {
      const idProducto = item.idProducto || item.id || null;
      const cantidad   = item.cantidad || 0;
      if (!idProducto || cantidad <= 0) continue;
      refs.push({ ref: db.collection("productos").doc(String(idProducto)), cantidad });
    }
    const snapshots = await Promise.all(refs.map((r) => transaction.get(r.ref)));
    for (let i = 0; i < refs.length; i++) {
      const snap = snapshots[i];
      const { ref, cantidad } = refs[i];
      if (!snap.exists) continue;
      const stockActual = snap.data().stock || 0;
      const nuevoStock  = Math.max(0, stockActual + signo * cantidad);
      transaction.update(ref, {
        stock: nuevoStock,
        ultimaActualizacionStock: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}


//  FUNCIÓN 2: generarReporteExcel

const G900='1B4332', G700='2D6A4F', G500='40916C', G300='74C69D';
const G100='D8F3DC', G50='F0FFF4',  G50v='E8F5E9';
const WHT='FFFFFF',  GR1='F8F9FA',  GR3='6C757D';
const BLK='212529',  ORNG='E67E22', BLU='1565C0';
const RED='C0392B',  GOLD='F39C12';
const BLU2='EBF5FB', RED2='FFEBEE';
const BLUDK='1B5E20', KCONF='C8E6C9', KTICK='BBDEFB';
const YLLO='FFF9C4', YLLOF='F57F17', GRN2='E8F5E9', RED3='FFEBEE';
const DSPC='E3F2FD', DSPCF='0D47A1';

// ── Colores tabla comparativa ──
const COMP_BG1='EBF5FB', COMP_BG2='E8F5E9', COMP_HD='1565C0', COMP_GN='2E7D32';

// Colores devoluciones — se reutilizan G900, G700, GR1, WHT del sistema

const STOCK_MIN_DEFAULT = 10;

function argb(hex6) { return 'FF' + hex6.toUpperCase(); }
function cellStyle(fg=BLK, bg=WHT, bold=false, size=10, italic=false, hAlign='left', wrapText=false) {
  return {
    font:      { name:'Calibri', color:{argb:argb(fg)}, bold, size, italic },
    fill:      { type:'pattern', pattern:'solid', fgColor:{argb:argb(bg)} },
    alignment: { horizontal:hAlign, vertical:'middle', wrapText },
  };
}
function applyStyle(cell, style) {
  cell.font = style.font; cell.fill = style.fill; cell.alignment = style.alignment;
}
function setCell(ws, row, col, value, style) {
  const cell = ws.getCell(row, col);
  cell.value = value;
  if (style) applyStyle(cell, style);
  return cell;
}
function fillRow(ws, row, numCols, bgHex) {
  for (let c = 1; c <= numCols; c++) {
    ws.getCell(row, c).fill = { type:'pattern', pattern:'solid', fgColor:{argb:argb(bgHex)} };
  }
}
function fmt(n) { return '$' + Number(n).toLocaleString('es-CO'); }

function estadoStock(s, min) {
  if (s <= 0)   return 'sinStock';
  if (s <= min) return 'bajo';
  return 'optimo';
}

function traducirMotivo(m) {
  const map = {
    defectuoso:          'Defectuoso',
    equivocado:          'Equivocado',
    cantidad_incorrecta: 'Cant. incorrecta',
    insatisfecho:        'Insatisfecho',
    otro:                'Otro',
  };
  return map[m] || m || '—';
}

function resumenProductosDev(productos) {
  if (!Array.isArray(productos) || productos.length === 0) return '—';
  return productos.map(p => `${p.cantidad||0}× ${p.nombre||'?'}`).join(' | ');
}

function motivoPrincipal(productos) {
  if (!Array.isArray(productos) || productos.length === 0) return '—';
  const motivos = [...new Set(productos.map(p => traducirMotivo(p.motivo || '')))];
  return motivos.join(', ');
}

function formatFecha(val) {
  if (!val) return '—';
  try {
    // Puede venir como ISO string (sanitizado desde Flutter)
    const d = new Date(typeof val === 'object' && val._seconds
      ? val._seconds * 1000
      : val);
    return d.toLocaleDateString('es-CO', {
      day:'2-digit', month:'2-digit', year:'numeric',
      hour:'2-digit', minute:'2-digit', hour12:false,
    });
  } catch(e) { return '—'; }
}

// ─────────────────────────────────────────────────────────────
// renderTablaComparativa
// ─────────────────────────────────────────────────────────────
function renderTablaComparativa(ws, filaInicio, totalPedidos, totalVentas, entregados, totalPedidosCount) {
  const diferencia    = totalPedidos - totalVentas;
  const pctCobrado    = totalPedidos > 0 ? (totalVentas / totalPedidos * 100) : 0;
  const pctPendCobro  = 100 - pctCobrado;

  setCell(ws, filaInicio, 3, '  TOTAL PEDIDOS vs TOTAL VENTAS (COBRADAS)', cellStyle(G700, WHT, true, 11));

  const fHdr = filaInicio + 1;
  ['Concepto', 'Valor', 'Pedidos', '% del Total', 'Notas'].forEach((h, i) =>
    setCell(ws, fHdr, 3+i, h, cellStyle(WHT, G700, true, 10, false, 'center'))
  );

  const f1 = fHdr + 1;
  setCell(ws, f1, 3, '📦  Total pedidos del período', cellStyle(BLK, GR1, false, 10));
  setCell(ws, f1, 4, fmt(Math.round(totalPedidos)),    cellStyle(G700, GR1, true, 11, false, 'center'));
  setCell(ws, f1, 5, String(totalPedidosCount),        cellStyle(BLK, GR1, false, 10, false, 'center'));
  setCell(ws, f1, 6, '100%',                           cellStyle(BLK, GR1, false, 10, false, 'center'));
  setCell(ws, f1, 7, 'Suma de TODOS los pedidos (cualquier estado)', cellStyle(GR3, GR1, false, 9, true));

  const f2 = f1 + 1;
  setCell(ws, f2, 3, '✅  Total ventas cobradas (entregados)', cellStyle(BLK, WHT, false, 10));
  setCell(ws, f2, 4, fmt(Math.round(totalVentas)),             cellStyle(G700, WHT, true, 11, false, 'center'));
  setCell(ws, f2, 5, String(entregados),                       cellStyle(BLK, WHT, false, 10, false, 'center'));
  setCell(ws, f2, 6, `${pctCobrado.toFixed(1)}%`,              cellStyle(G700, WHT, true, 10, false, 'center'));
  setCell(ws, f2, 7, 'Solo pedidos con estado "entregado"',    cellStyle(GR3, WHT, false, 9, true));

  const f3 = f2 + 1;
  setCell(ws, f3, 3, '⏳  En curso / aún no cobrado',   cellStyle(BLK, GR1, false, 10));
  setCell(ws, f3, 4, fmt(Math.round(diferencia)),        cellStyle(G700, GR1, true, 11, false, 'center'));
  setCell(ws, f3, 5, String(totalPedidosCount - entregados), cellStyle(BLK, GR1, false, 10, false, 'center'));
  setCell(ws, f3, 6, `${pctPendCobro.toFixed(1)}%`,     cellStyle(G700, GR1, true, 10, false, 'center'));
  setCell(ws, f3, 7, 'Pendiente + Confirmado + Despachado + Cancelado', cellStyle(GR3, GR1, false, 9, true));

  const fTot = f3 + 1;
  fillRow(ws, fTot, 8, G900);
  setCell(ws, fTot, 3, 'COBERTURA DE COBRO',            cellStyle(WHT,  G900, true, 10, false, 'left'));
  setCell(ws, fTot, 4, `${pctCobrado.toFixed(1)}% cobrado`, cellStyle(GOLD, G900, true, 12, false, 'center'));
  setCell(ws, fTot, 5, `${entregados} de ${totalPedidosCount}`, cellStyle(WHT, G900, true, 10, false, 'center'));
  [6,7].forEach(c => { ws.getCell(fTot, c).fill = { type:'pattern', pattern:'solid', fgColor:{argb:argb(G900)} }; });

  const fNota = fTot + 1;
  const noteCell = ws.getCell(fNota, 3);
  noteCell.value = 'ℹ  "Total pedidos" incluye todos los estados. "Total ventas" = solo entregados = dinero efectivamente cobrado.';
  noteCell.font  = { name:'Calibri', color:{argb:argb(GR3)}, size:9, italic:true };
  noteCell.alignment = { horizontal:'left', vertical:'middle' };
  ws.mergeCells(`C${fNota}:G${fNota}`);

  return fNota + 2;
}

// ─────────────────────────────────────────────────────────────
// renderResumenDevoluciones
// Dibuja el bloque de devoluciones en el Resumen Ejecutivo.
// Mismo estilo que el resto de tablas: encabezado G900, 
// filas alternas GR1/WHT. Sin colores naranjas.
// Retorna la fila siguiente disponible.
// ─────────────────────────────────────────────────────────────
function renderResumenDevoluciones(ws, filaInicio, devoluciones, numCols) {
  if (!devoluciones || devoluciones.length === 0) return filaInicio;

  const montoDev = devoluciones.reduce((s, d) => s + (d.montoDevolucion || 0), 0);
  let f = filaInicio;

  // Separador
  ws.getRow(f).height = 14; f++;

  // Título — igual que "DISTRIBUCIÓN POR ESTADO"
  ws.getRow(f).height = 22;
  setCell(ws, f, 3, '  DEVOLUCIONES DEL PERÍODO', cellStyle(G700, WHT, true, 11));
  f++;

  // Encabezados tabla — encabezado verde oscuro igual que las demás
  ws.getRow(f).height = 26;
  ['Fecha', 'N° Pedido', 'Cliente', 'Productos devueltos', 'Motivo', 'Resolución', 'Monto'].forEach((h, i) =>
    setCell(ws, f, 3+i, h, cellStyle(WHT, G700, true, 10, false, 'center'))
  );
  f++;

  // Filas — alternas GR1/WHT igual que Detalle Pedidos
  devoluciones.forEach((d, idx) => {
    const bg  = idx % 2 === 0 ? GR1 : WHT;
    const res = d.resolucion || '';
    const resLabel = res === 'reenvio' ? 'Reenvío' : res === 'reembolso' ? 'Reembolso' : res;

    ws.getRow(f).height = 22;
    setCell(ws, f, 3, formatFecha(d.fechaSolicitud),              cellStyle(GR3, bg, false, 9,  false, 'center'));
    setCell(ws, f, 4, d.numeroPedido || '—',                      cellStyle(G700,bg, true,  9,  false, 'center'));
    setCell(ws, f, 5, d.nombreCliente || '—',                     cellStyle(BLK, bg, false, 10, false, 'left'));
    setCell(ws, f, 6, resumenProductosDev(d.productosDevueltos),  cellStyle(BLK, bg, false, 9,  false, 'left', true));
    setCell(ws, f, 7, motivoPrincipal(d.productosDevueltos),      cellStyle(BLK, bg, false, 9,  false, 'center'));
    setCell(ws, f, 8, resLabel,                                    cellStyle(BLK, bg, true,  9,  false, 'center'));
    setCell(ws, f, 9, fmt(Math.round(d.montoDevolucion || 0)),     cellStyle(G700,bg, true,  10, false, 'center'));
    f++;
  });

  // Fila total — verde oscuro igual que TOTAL GENERAL de otras tablas
  ws.getRow(f).height = 26;
  fillRow(ws, f, numCols + 2, G900);
  setCell(ws, f, 3, 'TOTAL DEVOLUCIONES', cellStyle(WHT, G900, true, 10, false, 'left'));
  setCell(ws, f, 4, String(devoluciones.length), cellStyle(WHT, G900, true, 10, false, 'center'));
  setCell(ws, f, 9, fmt(Math.round(montoDev)), cellStyle(GOLD, G900, true, 12, false, 'center'));
  f++;

  // Nota al pie
  ws.getRow(f).height = 16;
  const nota = ws.getCell(f, 3);
  nota.value = 'ℹ  Solo se muestran devoluciones del período seleccionado. Monto = suma de productos devueltos × precio unitario.';
  nota.font = { name:'Calibri', color:{argb:argb(GR3)}, size:9, italic:true };
  nota.alignment = { horizontal:'left', vertical:'middle' };
  ws.mergeCells(`C${f}:I${f}`);
  f++;
  f++; // spacer

  return f;
}

async function generateXlsx(pedidos, periodo, productos = [], devoluciones = []) {
  const now    = new Date();
  const nowStr = now.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'})
               + '  ' + now.toLocaleTimeString('es-CO',{hour:'2-digit',minute:'2-digit',hour12:false});
  const dateStr = now.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});

  const total       = pedidos.length;
  const pendientes  = pedidos.filter(p=>p.estado==='pendiente').length;
  const confirmados = pedidos.filter(p=>p.estado==='confirmado').length;
  const despachados = pedidos.filter(p=>p.estado==='despachado').length;
  const entregados  = pedidos.filter(p=>p.estado==='entregado').length;
  const cancelados  = pedidos.filter(p=>p.estado==='cancelado').length;

  const totalVentas  = pedidos.filter(p=>p.estado==='entregado').reduce((s,p)=>s+(p.total||0),0);
  const totalPedidos = pedidos.reduce((s,p)=>s+(p.total||0),0);
  const ticket       = entregados > 0 ? totalVentas / entregados : 0;
  const tasaEntr = total > 0 ? (entregados  / total * 100) : 0;
  const pctPend  = total > 0 ? (pendientes  / total * 100) : 0;
  const pctConf  = total > 0 ? (confirmados / total * 100) : 0;
  const pctDesp  = total > 0 ? (despachados / total * 100) : 0;
  const pctEntr  = total > 0 ? (entregados  / total * 100) : 0;
  const pctCanc  = total > 0 ? (cancelados  / total * 100) : 0;

  const wb = new ExcelJS.Workbook();
  wb.creator = 'Granero del Norte Admin';
  wb.created = now;

  // ═══════════════════════════════════════════════════════════
  // HOJA 1: Resumen Ejecutivo
  // ═══════════════════════════════════════════════════════════
  const ws1 = wb.addWorksheet('Resumen Ejecutivo', { views:[{showGridLines:false}] });
  ws1.columns = [{width:1.5},{width:3},{width:22},{width:24.7},{width:16},{width:18},{width:25.9},{width:3}];

  const rh1 = {1:6,2:55,3:9,4:21,5:30,6:38,7:36,8:36,9:36,10:36,11:8,12:14,13:30,14:19,15:28,16:28,17:28,18:28,19:28,20:10};
  Object.entries(rh1).forEach(([r,h]) => { ws1.getRow(+r).height = h; });
  for(let r=21;r<=50;r++) ws1.getRow(r).height=22;

  fillRow(ws1, 1, 8, G900); fillRow(ws1, 2, 8, G900);
  setCell(ws1,2,3,'🌾  GRANERO DEL NORTE', cellStyle(WHT,G900,true,26,'normal','left'));
  setCell(ws1,2,5,'Reporte de Ventas & Pedidos', cellStyle(G300,G900,false,12,'normal','left'));
  setCell(ws1,2,6,`📅  ${nowStr}`, cellStyle(G300,G900,false,10,'normal','right'));
  setCell(ws1,2,7,`Período: ${periodo}`, cellStyle(WHT,G900,true,11,'normal','right'));

  setCell(ws1,4,3,'  INDICADORES CLAVE DE RENDIMIENTO', cellStyle(G700,WHT,true,11));
  const kpiBgs=[G100,KTICK,KCONF,G50v,RED2], kpiFCs=[G700,BLU,BLUDK,G500,RED], kpiAccBgs=[G700,BLU,BLUDK,G500,RED];
  for(let i=0;i<5;i++) ws1.getCell(5,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiBgs[i])}};
  ['📦','📈','💰','✅','❌'].forEach((em,i)=> setCell(ws1,6,3+i,em,cellStyle(BLK,kpiBgs[i],false,18,'normal','center')));
  ['TOTAL\nPEDIDOS','TICKET\nPROMEDIO','VENTAS\nCOBRADAS','TASA DE\nENTREGA','CANCELADOS']
    .forEach((lbl,i)=> setCell(ws1,7,3+i,lbl,cellStyle(kpiFCs[i],kpiBgs[i],true,8,'normal','center',true)));
  [String(total),fmt(Math.round(ticket)),fmt(Math.round(totalVentas)),`${tasaEntr.toFixed(1)}%`,`${pctCanc.toFixed(1)}%`]
    .forEach((val,i)=> setCell(ws1,8,3+i,val,cellStyle(kpiFCs[i],kpiBgs[i],true,20,'normal','center')));
  ['en el período','por pedido entregado','solo entregados',`${entregados} de ${total} pedidos`,`${cancelados} pedido(s)`]
    .forEach((sub,i)=> setCell(ws1,9,3+i,sub,cellStyle(GR3,kpiBgs[i],false,8,true,'center')));
  for(let i=0;i<5;i++) ws1.getCell(10,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiAccBgs[i])}};

  setCell(ws1,12,3,'  DISTRIBUCIÓN POR ESTADO',cellStyle(G700,WHT,true,11));
  ['Estado','Pedidos','% Total','Ingresos ($)','Participación Visual']
    .forEach((h,i)=> setCell(ws1,13,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));

  [
    [`🟡  Pendiente`,  pendientes,  pctPend, null,        GR1,  ORNG ],
    [`🔵  Confirmado`, confirmados, pctConf, null,        BLU2, BLU  ],
    [`🚚  Despachado`, despachados, pctDesp, null,        DSPC, DSPCF],
    [`🟢  Entregado`,  entregados,  pctEntr, totalVentas, G100, G500 ],
    [`🔴  Cancelado`,  cancelados,  pctCanc, null,        RED2, RED  ],
  ].forEach(([lbl,cnt,pct,ing,bg,acc],idx) => {
    const r=14+idx;
    setCell(ws1,r,3,lbl,cellStyle(BLK,bg,false,10,'normal','left'));
    setCell(ws1,r,4,cnt,cellStyle(acc,bg,true,10,'normal','center'));
    setCell(ws1,r,5,`${pct.toFixed(1)}%`,cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws1,r,6,ing>0?fmt(Math.round(ing)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
    const filled = Math.max(0, Math.min(20, Math.round(pct / 100 * 20)));
    const barStr = '█'.repeat(filled) + '░'.repeat(20 - filled) + `  ${pct.toFixed(1)}%`;
    setCell(ws1,r,7,barStr,cellStyle(acc,bg,true,8,'normal','left'));
  });

  ws1.getRow(20).height = 14;

  // ── Tabla comparativa ────────────────────────────────────
  const filaPostComp = renderTablaComparativa(ws1, 21, totalPedidos, totalVentas, entregados, total);

  // ── Bloque devoluciones en Resumen Ejecutivo ─────────────
  const filaPostDev = renderResumenDevoluciones(ws1, filaPostComp, devoluciones, 7);

  fillRow(ws1, filaPostDev, 8, G900);

  // ═══════════════════════════════════════════════════════════
  // HOJA 2: Detalle Pedidos
  // ═══════════════════════════════════════════════════════════
  const ws2=wb.addWorksheet('Detalle Pedidos',{views:[{showGridLines:false}]});
  ws2.columns=[{width:1.5},{width:3},{width:22},{width:28},{width:16},{width:18},{width:22},{width:3}];
  ws2.getRow(1).height=6; ws2.getRow(2).height=48; ws2.getRow(3).height=8; ws2.getRow(4).height=28;
  for(let r=5;r<5+pedidos.length+3;r++) ws2.getRow(r).height=24;
  ws2.getRow(5+pedidos.length).height=28;
  for(let r=5+pedidos.length+2;r<=5+pedidos.length+12;r++) ws2.getRow(r).height=22;

  fillRow(ws2,1,8,G900); fillRow(ws2,2,8,G900);
  setCell(ws2,2,3,'📋  DETALLE DE PEDIDOS',cellStyle(WHT,G900,true,20,'normal','left'));
  setCell(ws2,2,6,`Actualizado: ${dateStr}`,cellStyle(G300,G900,false,10,'normal','right'));
  setCell(ws2,2,7,`Período: ${periodo}`,cellStyle(WHT,G900,true,11,'normal','right'));
  ['N° Pedido','Cliente','Estado','Total ($)','Fecha']
    .forEach((h,i)=> setCell(ws2,4,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));

  const estEmoji={entregado:'🟢',confirmado:'🔵',despachado:'🚚',pendiente:'🟡',cancelado:'🔴'};
  const estFC2={entregado:G500,confirmado:BLU,despachado:DSPCF,pendiente:ORNG,cancelado:RED};
  pedidos.forEach((p,idx)=>{
    const r=5+idx, bg=idx%2===0?WHT:G50, est=p.estado||'pendiente';
    const fc=estFC2[est]||GR3, em=estEmoji[est]||'⚪', tot=p.total||0;
    let fechaStr='—';
    try{fechaStr=new Date(p.fechaPedido).toLocaleString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',hour12:false});}catch(e){}
    setCell(ws2,r,3,getNumeroPedido(p),cellStyle(G700,bg,true,9,'normal','center'));
    setCell(ws2,r,4,p.nombreCliente||'—',cellStyle(BLK,bg,false,10,'normal','left'));
    setCell(ws2,r,5,`${em}  ${est.charAt(0).toUpperCase()+est.slice(1)}`,cellStyle(fc,bg,true,9,'normal','center'));
    setCell(ws2,r,6,fmt(tot),cellStyle(G700,bg,true,11,'normal','center'));
    setCell(ws2,r,7,fechaStr,cellStyle(GR3,bg,false,9,'normal','center'));
  });

  const tr2=5+pedidos.length;
  setCell(ws2,tr2,3,'TOTAL GENERAL (todos los pedidos)',cellStyle(WHT,G900,true,10,'normal','center'));
  [4,5,7].forEach(c=>{ws2.getCell(tr2,c).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};});
  setCell(ws2,tr2,6,fmt(totalPedidos),cellStyle(GOLD,G900,true,13,'normal','center'));

  fillRow(ws2,tr2+2,8,G900);

  // ═══════════════════════════════════════════════════════════
  // HOJA 3: Análisis
  // ═══════════════════════════════════════════════════════════
  const ws3=wb.addWorksheet('Análisis',{views:[{showGridLines:false}]});
  ws3.columns=[{width:1.5},{width:3},{width:22},{width:16},{width:18},{width:16},{width:20},{width:14}];
  const rh3={1:6,2:48,3:8,4:26,5:26,6:24,7:24,8:24,9:24,10:24,11:26,12:12,13:26,14:26};
  Object.entries(rh3).forEach(([r,h])=>{ws3.getRow(+r).height=h;});
  for(let r=15;r<=22;r++) ws3.getRow(r).height=22;
  ws3.getRow(23).height=26;
  for(let r=24;r<=45;r++) ws3.getRow(r).height=22;

  fillRow(ws3,1,8,G900); fillRow(ws3,2,8,G900);
  setCell(ws3,2,3,'📈  ANÁLISIS DE VENTAS',cellStyle(WHT,G900,true,20,'normal','left'));
  setCell(ws3,4,3,'  ANÁLISIS POR ESTADO',cellStyle(G700,WHT,true,11,'normal','left'));
  ['Estado','Pedidos','Ventas ($)','% Participación','Ticket Prom.','Tendencia']
    .forEach((h,i)=> setCell(ws3,5,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));

  const tkEntr = entregados > 0 ? totalVentas / entregados : 0;
  [
    ['🟡  Pendiente',  pendientes,  null,        pctPend, null,   '→  Sin cambios',  GR1,  ORNG,  true ],
    ['🔵  Confirmado', confirmados, null,        pctConf, null,   '↑  En proceso',   BLU2, BLU,   false],
    ['🚚  Despachado', despachados, null,        pctDesp, null,   '↑  En camino',    DSPC, DSPCF, true ],
    ['🟢  Entregado',  entregados,  totalVentas, pctEntr, tkEntr, '✅  Completado',  G100, G500,  true ],
    ['🔴  Cancelado',  cancelados,  null,        pctCanc, null,   '↓  Perdida',      RED2, RED,   true ],
  ].forEach(([lbl,cnt,ing,pct,tk,tend,bg,acc,bld],idx)=>{
    const r=6+idx;
    setCell(ws3,r,3,lbl,cellStyle(acc,bg,bld,10,'normal','left'));
    setCell(ws3,r,4,cnt,cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,5,ing>0?fmt(Math.round(ing)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,6,`${pct.toFixed(1)}%`,cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,7,tk>0?fmt(Math.round(tk)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,8,tend,cellStyle(BLK,bg,true,10,'normal','center'));
  });

  setCell(ws3,11,3,'TOTAL GENERAL (todos los pedidos)',cellStyle(WHT,G900,true,10,'normal','left'));
  setCell(ws3,11,4,String(total),cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,11,5,fmt(Math.round(totalPedidos)),cellStyle(GOLD,G900,true,10,'normal','center'));
  setCell(ws3,11,6,'100%',cellStyle(WHT,G900,true,10,'normal','center'));
  ws3.getCell(11,7).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};
  ws3.getCell(11,8).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};

  setCell(ws3,13,3,'  TENDENCIA DIARIA — Últimos 7 días',cellStyle(G700,WHT,true,11,'normal','left'));
  ['Fecha','Total pedidos ($)','Ventas cobradas ($)','Ticket prom. (cobrado)']
    .forEach((h,i)=> setCell(ws3,14,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));

  const daysMap={};
  pedidos.forEach(p=>{
    try{
      const d=new Date(p.fechaPedido);
      const key=d.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});
      if(!daysMap[key]) daysMap[key]=[];
      daysMap[key].push(p);
    }catch(e){}
  });
  const dayAbbr=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  let totalPedidosSemana=0, totalVentasSemana=0;
  for(let i=0;i<7;i++){
    const day=new Date(now);
    day.setDate(now.getDate()-(6-i));
    const r=15+i;
    const key=day.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});
    const abbr=dayAbbr[(day.getDay()+6)%7];
    const label=`${key} (${abbr})`;
    const peds=daysMap[key]||[];
    const totDia = peds.reduce((s,p)=>s+(p.total||0),0);
    const pedsEntregados = peds.filter(p=>p.estado==='entregado');
    const ventasDia = pedsEntregados.reduce((s,p)=>s+(p.total||0),0);
    const tkDay = pedsEntregados.length > 0 ? ventasDia / pedsEntregados.length : 0;
    const bg=i%2===0?G50:WHT;
    totalPedidosSemana += totDia;
    totalVentasSemana  += ventasDia;
    setCell(ws3,r,3,label,cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,4,totDia>0?fmt(Math.round(totDia)):'—',cellStyle(DSPCF,bg,true,10,'normal','center'));
    setCell(ws3,r,5,ventasDia>0?fmt(Math.round(ventasDia)):'—',cellStyle(G700,bg,true,10,'normal','center'));
    setCell(ws3,r,6,tkDay>0?fmt(Math.round(tkDay)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
  }
  setCell(ws3,23,3,'TOTAL SEMANA',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,23,4,totalPedidosSemana>0?fmt(Math.round(totalPedidosSemana)):'—',cellStyle(DSPCF,G900,true,10,'normal','center'));
  setCell(ws3,23,5,totalVentasSemana>0?fmt(Math.round(totalVentasSemana)):'—',cellStyle(GOLD,G900,true,10,'normal','center'));
  ws3.getCell(23,6).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};
  ws3.getCell(23,7).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};

  fillRow(ws3,24,8,G900);

  // ═══════════════════════════════════════════════════════════
  // HOJA 4: Stock de Productos
  // ═══════════════════════════════════════════════════════════
  if (productos.length > 0) {
    const ws4 = wb.addWorksheet('Stock de Productos', { views:[{showGridLines:false}] });
    ws4.columns = [
      {width:1.5},{width:3},{width:32},{width:18},{width:10},
      {width:16},{width:22},{width:22},{width:16},{width:16},
    ];
    const totalP     = productos.length;
    const sinStockN  = productos.filter(p => estadoStock(p.stock||0, p.stockMinimo||STOCK_MIN_DEFAULT)==='sinStock').length;
    const bajosN     = productos.filter(p => estadoStock(p.stock||0, p.stockMinimo||STOCK_MIN_DEFAULT)==='bajo').length;
    const okN        = totalP - sinStockN - bajosN;
    const valorInv     = productos.reduce((s,p)=>s+((p.stock||0)*(p.precio||p.precioVenta||0)),0);
    const valorInvProv = productos.reduce((s,p)=>s+((p.stock||0)*(p.precioProveedor||0)),0);
    const gananciaPot  = valorInv - valorInvProv;
    const margenTotal  = valorInv > 0 ? (gananciaPot / valorInv * 100) : 0;
    const rh4={1:6,2:52,3:9,4:20,5:28,6:28,7:28,8:28,9:10};
    Object.entries(rh4).forEach(([r,h])=>{ws4.getRow(+r).height=h;});
    for(let r=10;r<10+totalP+4;r++) ws4.getRow(r).height=22;
    ws4.getRow(10+totalP).height=28;
    fillRow(ws4,1,10,G900); fillRow(ws4,2,10,G900);
    setCell(ws4,2,3,'📦  STOCK DE PRODUCTOS',    cellStyle(WHT, G900,true, 24,false,'left'));
    setCell(ws4,2,5,'Inventario en tiempo real',  cellStyle(G300,G900,false,11,false,'left'));
    setCell(ws4,2,7,`📅  ${nowStr}`,              cellStyle(G300,G900,false,10,false,'right'));
    setCell(ws4,2,8,`Total: ${totalP} productos`, cellStyle(WHT, G900,true, 11,false,'right'));
    setCell(ws4,4,3,'  RESUMEN DE INVENTARIO',    cellStyle(G700,WHT, true, 11));
    const kpiP=[
      ['📦','TOTAL\nPRODUCTOS',    String(totalP),                                                      'en catálogo',                G100, G700    ],
      ['✅','STOCK\nÓPTIMO',       String(okN),                                                         'disponibles',                GRN2, '2E7D32'],
      ['⚠️','STOCK\nBAJO',         String(bajosN),                                                      'por reabastecer',            YLLO, YLLOF   ],
      ['❌','SIN\nSTOCK',          String(sinStockN),                                                   'agotados',                   RED3, RED     ],
      ['💰','VALOR INV.\nVENTA',   `$${Number(Math.round(valorInv)).toLocaleString('es-CO')}`,           'precio venta × stock',       G100, G700    ],
      ['🏭','VALOR INV.\nCOSTO',   `$${Number(Math.round(valorInvProv)).toLocaleString('es-CO')}`,       'precio costo × stock',       YLLO, YLLOF   ],
      ['📈','GANANCIA\nPOTENCIAL', `$${Number(Math.round(gananciaPot)).toLocaleString('es-CO')}`,        'venta − costo inventario',   GRN2, '2E7D32'],
      ['🎯','MARGEN\nTOTAL',       valorInv>0?`${margenTotal.toFixed(1)}%`:'—',                         'ganancia sobre precio venta', GRN2, '2E7D32'],
    ];
    for(let i=0;i<8;i++) ws4.getCell(5,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiP[i][4])}};
    kpiP.forEach(([em,lbl,val,sub,bg,fc],i)=>{
      setCell(ws4,6,3+i,em, cellStyle(BLK,bg,false,16,false,'center'));
      setCell(ws4,7,3+i,lbl,cellStyle(fc, bg,true,  8,false,'center',true));
      setCell(ws4,8,3+i,val,cellStyle(fc, bg,true, 14,false,'center'));
      setCell(ws4,9,3+i,sub,cellStyle(GR3,bg,false, 8,true, 'center'));
    });
    const HDR=10;
    ['Producto','Categoría','Stock','Estado','Precio venta x Und.','Precio costo x Und.','% Ganancia']
      .forEach((h,i)=>setCell(ws4,HDR,3+i,h,cellStyle(WHT,G700,true,10,false,'center')));
    const sorted=[...productos].sort((a,b)=>{
      const o=p=>{const e=estadoStock(p.stock||0,p.stockMinimo||STOCK_MIN_DEFAULT);if(e==='sinStock')return 0;if(e==='bajo')return 1;return 2;};
      return o(a)-o(b);
    });
    sorted.forEach((p,idx)=>{
      const r=HDR+1+idx, s=p.stock||0, min=p.stockMinimo||STOCK_MIN_DEFAULT;
      const precio=p.precio||p.precioVenta||0, costo=p.precioProveedor||0;
      const pctGan=precio>0?((precio-costo)/precio*100):0;
      const est=estadoStock(s,min);
      let bg,estadoTxt,estadoFC;
      if(est==='sinStock'){bg=RED3;estadoTxt='❌  Sin stock';estadoFC=RED;}
      else if(est==='bajo'){bg=YLLO;estadoTxt='⚠️  Stock bajo';estadoFC=YLLOF;}
      else{bg=GRN2;estadoTxt='✅  Óptimo';estadoFC='2E7D32';}
      const pctFC=pctGan>=0?'2E7D32':RED;
      setCell(ws4,r,3,p.nombre||p.name||'—',   cellStyle(BLK,    bg,false,10,false,'left'));
      setCell(ws4,r,4,p.categoria||'—',         cellStyle(GR3,    bg,false,10,false,'center'));
      setCell(ws4,r,5,s,                        cellStyle(estadoFC,bg,true, 12,false,'center'));
      setCell(ws4,r,6,estadoTxt,                cellStyle(estadoFC,bg,true,  9,false,'center'));
      setCell(ws4,r,7,precio>0?fmt(precio):'—', cellStyle(G700,   bg,false,10,false,'center'));
      setCell(ws4,r,8,costo>0 ?fmt(costo) :'—', cellStyle(ORNG,   bg,false,10,false,'center'));
      setCell(ws4,r,9,costo>0?`${pctGan.toFixed(1)}%`:'—',cellStyle(pctFC,bg,true,10,false,'center'));
    });
    const trP=HDR+1+sorted.length;
    fillRow(ws4,trP,10,G900);
    setCell(ws4,trP,3,'TOTAL PRODUCTOS',cellStyle(WHT,G900,true,10,false,'center'));
    setCell(ws4,trP,5,String(totalP),   cellStyle(WHT,G900,true,10,false,'center'));
    setCell(ws4,trP,7,`$${Number(Math.round(valorInv)).toLocaleString('es-CO')}`,    cellStyle(GOLD,G900,true,12,false,'center'));
    setCell(ws4,trP,8,`$${Number(Math.round(valorInvProv)).toLocaleString('es-CO')}`,cellStyle(GOLD,G900,true,12,false,'center'));
    setCell(ws4,trP,9,valorInv>0?`${margenTotal.toFixed(1)}% margen`:'—',           cellStyle(GOLD,G900,true,10,false,'center'));
    const nrP=trP+2;
    const noteP=ws4.getCell(nrP,3);
    noteP.value=`ℹ  Stock en tiempo real · Umbral de stock bajo: ${STOCK_MIN_DEFAULT} unidades (o el stockMinimo del producto). % Ganancia = (Precio venta − Precio costo) / Precio venta.`;
    noteP.font={name:'Calibri',color:{argb:argb(GR3)},size:9,italic:true};
    noteP.alignment={horizontal:'left',vertical:'middle'};
    ws4.mergeCells(`C${nrP}:J${nrP}`);
    fillRow(ws4,nrP+2,10,G900);
  }


  const buf = await wb.xlsx.writeBuffer();
  return Buffer.from(buf);
}

exports.generarReporteExcel = functions
  .runWith({ memory: '256MB', timeoutSeconds: 60 })
  .https.onRequest((req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Método no permitido' }); return; }
    (async () => {
      try {
        const { pedidos = [], periodo = 'Este mes', productos = [], devoluciones = [] } = req.body;
        const xlsxBuf = await generateXlsx(pedidos, periodo, productos, devoluciones);
        res.status(200).json({
          base64:   xlsxBuf.toString('base64'),
          filename: `reporte_granmolino_${new Date().toISOString().slice(0,10)}.xlsx`,
        });
      } catch (e) {
        console.error("Error generando Excel:", e);
        res.status(500).json({ error: e.message });
      }
    })();
  });


//  FUNCIÓN 3: crearAdminUsuario

exports.crearAdminUsuario = functions
  .runWith({ memory: '256MB', timeoutSeconds: 60 })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
    }
    const callerDoc = await db.collection('administradores').doc(context.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().rol !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied', 'Solo super admins pueden crear admins');
    }
    const { nombre, email, password, negocio, fechaVencimiento } = data;
    if (!nombre || !email || !password || !negocio || !fechaVencimiento) {
      throw new functions.https.HttpsError('invalid-argument', 'Faltan campos requeridos');
    }
    try {
      const userRecord = await admin.auth().createUser({
        email:         email.trim(),
        password:      password.trim(),
        displayName:   nombre.trim(),
        emailVerified: false,
      });
      await db.collection('administradores').doc(userRecord.uid).set({
        nombre:           nombre.trim(),
        email:            email.trim(),
        rol:              'admin',
        activo:           true,
        primerLogin:      true,
        negocio:          negocio.trim(),
        fechaVencimiento: admin.firestore.Timestamp.fromDate(new Date(fechaVencimiento)),
        creadoEn:         admin.firestore.FieldValue.serverTimestamp(),
        creadoPor:        context.auth.uid,
        ultimoAcceso:     null,
      });
      return { exito: true, uid: userRecord.uid, mensaje: 'Administrador creado exitosamente' };
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        throw new functions.https.HttpsError('already-exists', 'Este email ya está registrado');
      }
      throw new functions.https.HttpsError('internal', e.message);
    }
  });


//  FUNCIÓN 4: backupDiario

exports.backupDiario = functions
  .runWith({ memory: '512MB', timeoutSeconds: 300 })
  .pubsub.schedule('0 0 * * *')
  .timeZone('America/Bogota')
  .onRun(async () => {
    const storage = admin.storage().bucket();
    const ahora   = new Date();

    const COLECCIONES = ['pedido', 'productos', 'usuarios', 'detalle_pedido', 'venta'];

    function serializar(v) {
      if (v === null || v === undefined) return v;
      if (v instanceof admin.firestore.Timestamp) {
        return { __tipo: 'Timestamp', iso: v.toDate().toISOString() };
      }
      if (v instanceof admin.firestore.GeoPoint) {
        return { __tipo: 'GeoPoint', lat: v.latitude, lng: v.longitude };
      }
      if (Array.isArray(v)) return v.map(serializar);
      if (typeof v === 'object') {
        const result = {};
        for (const key of Object.keys(v)) result[key] = serializar(v[key]);
        return result;
      }
      return v;
    }

    const datos   = {};
    let totalDocs = 0;

    for (const col of COLECCIONES) {
      try {
        const snap = await db.collection(col).get();
        datos[col] = {};
        snap.forEach((doc) => {
          datos[col][doc.id] = serializar(doc.data());
          totalDocs++;
        });
        console.log(`✅ ${col}: ${snap.size} docs`);
      } catch (e) {
        console.warn(`⚠️ No se pudo leer ${col}: ${e.message}`);
        datos[col] = {};
      }
    }

    const exportFinal = {
      metadata: {
        fecha:           ahora.toISOString(),
        version:         '1.0',
        tipo:            'automatico',
        colecciones:     COLECCIONES,
        totalDocumentos: totalDocs,
        origen:          'cloud-function',
      },
      datos,
    };

    const jsonStr     = JSON.stringify(exportFinal, null, 2);
    const buffer      = Buffer.from(jsonStr, 'utf8');
    const fechaStr    = ahora.toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const rutaArchivo = `backups/sistema/backup_${fechaStr}.json`;

    try {
      await storage.file(rutaArchivo).save(buffer, {
        metadata: { contentType: 'application/json' },
      });

      const tamanoKB = Math.round(buffer.length / 1024);
      console.log(`✅ Backup guardado: ${rutaArchivo} (${totalDocs} docs, ${tamanoKB} KB)`);

      await db.collection('sistema').doc('ultimoBackup').set({
        fecha:      admin.firestore.Timestamp.fromDate(ahora),
        exito:      true,
        ruta:       rutaArchivo,
        totalDocs,
        tamanoKB,
        error:      null,
        origen:     'cloud-function',
      });

    } catch (e) {
      console.error('❌ Error guardando backup:', e.message);
      await db.collection('sistema').doc('ultimoBackup').set({
        fecha:     admin.firestore.Timestamp.fromDate(ahora),
        exito:     false,
        error:     e.message,
        totalDocs: 0,
        tamanoKB:  0,
        origen:    'cloud-function',
      }).catch(() => {});
    }

    try {
      const [archivos] = await storage.getFiles({ prefix: 'backups/sistema/' });
      const limite     = new Date();
      limite.setDate(limite.getDate() - 30);

      let eliminados = 0;
      for (const archivo of archivos) {
        const [meta] = await archivo.getMetadata();
        if (new Date(meta.timeCreated) < limite) {
          await archivo.delete();
          eliminados++;
          console.log(`🗑️ Eliminado: ${archivo.name}`);
        }
      }
      console.log(`[limpieza] ${eliminados} archivos eliminados`);
    } catch (e) {
      console.warn('⚠️ Error en limpieza:', e.message);
    }

    return null;
  });