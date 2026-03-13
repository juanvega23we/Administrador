const functions = require("firebase-functions");
const admin     = require("firebase-admin");
const ExcelJS   = require("exceljs");
const cors      = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

function getNumeroPedido(p) {
  return p.numeroPedido || p.idPedido || p.numero || p.id || p.codigo || '—';
}

// ═══════════════════════════════════════════════════════════════
//  FUNCIÓN 1: onPedidoUpdated
// ═══════════════════════════════════════════════════════════════
exports.onPedidoUpdated = functions.firestore
  .document("pedido/{pedidoId}")
  .onUpdate(async (change, context) => {
    const antes   = change.before.data();
    const despues = change.after.data();
    const estadoAntes   = antes?.estado;
    const estadoDespues = despues?.estado;

    if (!estadoAntes || !estadoDespues) return null;
    if (estadoAntes === estadoDespues) return null;

    const estadosValidos = ['pendiente', 'confirmado', 'entregado', 'cancelado'];
    if (!estadosValidos.includes(estadoAntes) || !estadosValidos.includes(estadoDespues)) return null;

    const pedidoId = context.params.pedidoId;
    const idPedido = despues.idPedido || pedidoId;

    if (estadoDespues === "confirmado" && estadoAntes === "pendiente") {
      await ajustarStock(idPedido, pedidoId, -1);
    }
    if (estadoDespues === "cancelado" && estadoAntes === "confirmado") {
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
    items = detallesSnap.docs.map((d) => d.data());
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

// ═══════════════════════════════════════════════════════════════
//  FUNCIÓN 2: generarReporteExcel
// ═══════════════════════════════════════════════════════════════
const G900='1B4332', G700='2D6A4F', G500='40916C', G300='74C69D';
const G100='D8F3DC', G50='F0FFF4',  G50v='E8F5E9';
const WHT='FFFFFF',  GR1='F8F9FA',  GR3='6C757D';
const BLK='212529',  ORNG='E67E22', BLU='1565C0';
const RED='C0392B',  GOLD='F39C12';
const BLU2='EBF5FB', RED2='FFEBEE';
const BLUDK='1B5E20', KCONF='C8E6C9', KTICK='BBDEFB';
const YLLO='FFF9C4', YLLOF='F57F17', GRN2='E8F5E9', RED3='FFEBEE';

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
function bar(pct, length=20) {
  const filled = Math.max(0, Math.min(length, Math.round(pct / 100 * length)));
  return '█'.repeat(filled) + '░'.repeat(length - filled) + `  ${pct.toFixed(1)}%`;
}
function fmt(n) { return '$' + Number(n).toLocaleString('es-CO'); }

function estadoStock(s, min) {
  if (s <= 0)   return 'sinStock';
  if (s <= min) return 'bajo';
  return 'optimo';
}

async function generateXlsx(pedidos, periodo, productos = []) {
  const now    = new Date();
  const nowStr = now.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'})
               + '  ' + now.toLocaleTimeString('es-CO',{hour:'2-digit',minute:'2-digit',hour12:false});
  const dateStr = now.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});

  const total       = pedidos.length;
  const pendientes  = pedidos.filter(p=>p.estado==='pendiente').length;
  const confirmados = pedidos.filter(p=>p.estado==='confirmado').length;
  const entregados  = pedidos.filter(p=>p.estado==='entregado').length;
  const cancelados  = pedidos.filter(p=>p.estado==='cancelado').length;
  const ingConf     = pedidos.filter(p=>p.estado==='confirmado').reduce((s,p)=>s+(p.total||0),0);
  const ingEntr     = pedidos.filter(p=>p.estado==='entregado').reduce((s,p)=>s+(p.total||0),0);
  const ingresos    = ingConf + ingEntr;
  const activos     = total - cancelados;
  const ticket      = activos > 0 ? ingresos / activos : 0;
  const tasaEntr    = total > 0 ? (entregados  / total * 100) : 0;
  const pctPend     = total > 0 ? (pendientes  / total * 100) : 0;
  const pctConf     = total > 0 ? (confirmados / total * 100) : 0;
  const pctEntr     = total > 0 ? (entregados  / total * 100) : 0;
  const pctCanc     = total > 0 ? (cancelados  / total * 100) : 0;

  const wb = new ExcelJS.Workbook();
  wb.creator = 'Granero del Norte Admin';
  wb.created = now;

  // ── Hoja 1: Resumen Ejecutivo ─────────────────────────────
  const ws1 = wb.addWorksheet('Resumen Ejecutivo', { views:[{showGridLines:false}] });
  ws1.columns = [{width:1.5},{width:3},{width:22},{width:24.7},{width:16},{width:18},{width:25.9},{width:3}];
  const rh1 = {1:6,2:55,3:9,4:21,5:30,6:38,7:36,8:36,9:36,10:36,11:8,12:14,13:30,14:19,15:28,16:28,17:28,18:28,19:10,20:10,21:5};
  Object.entries(rh1).forEach(([r,h]) => { ws1.getRow(+r).height = h; });
  fillRow(ws1, 1, 8, G900); fillRow(ws1, 2, 8, G900);
  setCell(ws1,2,3,'🌾  GRANERO DEL NORTE', cellStyle(WHT,G900,true,26,'normal','left'));
  setCell(ws1,2,5,'Reporte de Ventas & Pedidos', cellStyle(G300,G900,false,12,'normal','left'));
  setCell(ws1,2,6,`📅  ${nowStr}`, cellStyle(G300,G900,false,10,'normal','right'));
  setCell(ws1,2,7,`Período: ${periodo}`, cellStyle(WHT,G900,true,11,'normal','right'));
  setCell(ws1,4,3,'  INDICADORES CLAVE DE RENDIMIENTO', cellStyle(G700,WHT,true,11));
  const kpiBgs=[G100,KCONF,KTICK,G50v,RED2], kpiFCs=[G700,BLUDK,BLU,G500,RED], kpiAccBgs=[G700,BLUDK,BLU,G500,RED];
  for(let i=0;i<5;i++) ws1.getCell(5,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiBgs[i])}};
  ['📦','💰','📈','✅','❌'].forEach((em,i)=> setCell(ws1,6,3+i,em,cellStyle(BLK,kpiBgs[i],false,18,'normal','center')));
  ['TOTAL\nPEDIDOS','INGRESOS\nTOTALES','TICKET\nPROMEDIO','TASA DE\nENTREGA','CANCELADOS']
    .forEach((lbl,i)=> setCell(ws1,7,3+i,lbl,cellStyle(kpiFCs[i],kpiBgs[i],true,8,'normal','center',true)));
  [String(total),fmt(Math.round(ingresos)),fmt(Math.round(ticket)),`${tasaEntr.toFixed(1)}%`,`${pctCanc.toFixed(1)}%`]
    .forEach((val,i)=> setCell(ws1,8,3+i,val,cellStyle(kpiFCs[i],kpiBgs[i],true,20,'normal','center')));
  ['en el período','conf + entregados','por pedido activo',`${entregados} de ${total} pedidos`,`${cancelados} pedido cancelado`]
    .forEach((sub,i)=> setCell(ws1,9,3+i,sub,cellStyle(GR3,kpiBgs[i],false,8,true,'center')));
  for(let i=0;i<5;i++) ws1.getCell(10,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiAccBgs[i])}};
  setCell(ws1,12,3,'  DISTRIBUCIÓN POR ESTADO',cellStyle(G700,WHT,true,11));
  ['Estado','Pedidos','% Total','Ingresos ($)','Participación Visual']
    .forEach((h,i)=> setCell(ws1,13,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));
  [[`🟡  Pendiente`,pendientes,pctPend,null,GR1,ORNG],[`🔵  Confirmado`,confirmados,pctConf,ingConf,BLU2,BLU],
   [`🟢  Entregado`,entregados,pctEntr,ingEntr,G100,G500],[`🔴  Cancelado`,cancelados,pctCanc,null,RED2,RED]]
    .forEach(([lbl,cnt,pct,ing,bg,acc],idx) => {
      const r=14+idx;
      setCell(ws1,r,3,lbl,cellStyle(BLK,bg,false,10,'normal','left'));
      setCell(ws1,r,4,cnt,cellStyle(acc,bg,true,10,'normal','center'));
      setCell(ws1,r,5,`${pct.toFixed(1)}%`,cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws1,r,6,ing>0?fmt(Math.round(ing)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws1,r,7,bar(pct),cellStyle(acc,bg,true,8,'normal','left'));
    });
  setCell(ws1,18,3,'TOTAL GENERAL',cellStyle(WHT,G900,true,10,'normal','left'));
  setCell(ws1,18,4,String(total),cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws1,18,5,'100%',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws1,18,6,fmt(Math.round(ingresos)),cellStyle(WHT,G900,true,10,'normal','center'));
  ws1.getCell(18,7).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};
  const noteCell1=ws1.getCell(20,3);
  noteCell1.value='★  Generado automáticamente · Granero del Norte Admin · Datos en tiempo real desde Firestore';
  noteCell1.font={name:'Calibri',color:{argb:argb(GR3)},size:9,italic:true};
  noteCell1.alignment={horizontal:'left',vertical:'middle'};
  ws1.mergeCells('C20:G20');
  fillRow(ws1,21,8,G900);

  // ── Hoja 2: Detalle Pedidos ───────────────────────────────
  const ws2=wb.addWorksheet('Detalle Pedidos',{views:[{showGridLines:false}]});
  ws2.columns=[{width:1.5},{width:3},{width:22},{width:28},{width:16},{width:18},{width:22},{width:3}];
  ws2.getRow(1).height=6; ws2.getRow(2).height=48; ws2.getRow(3).height=8; ws2.getRow(4).height=28;
  for(let r=5;r<5+pedidos.length+3;r++) ws2.getRow(r).height=24;
  ws2.getRow(5+pedidos.length).height=28;
  fillRow(ws2,1,8,G900); fillRow(ws2,2,8,G900);
  setCell(ws2,2,3,'📋  DETALLE DE PEDIDOS',cellStyle(WHT,G900,true,20,'normal','left'));
  setCell(ws2,2,6,`Actualizado: ${dateStr}`,cellStyle(G300,G900,false,10,'normal','right'));
  setCell(ws2,2,7,`Período: ${periodo}`,cellStyle(WHT,G900,true,11,'normal','right'));
  ['N° Pedido','Cliente','Estado','Total ($)','Fecha']
    .forEach((h,i)=> setCell(ws2,4,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));
  const estEmoji={entregado:'🟢',confirmado:'🔵',pendiente:'🟡',cancelado:'🔴'};
  const estFC2={entregado:G500,confirmado:BLU,pendiente:ORNG,cancelado:RED};
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
  setCell(ws2,tr2,3,'TOTAL GENERAL',cellStyle(WHT,G900,true,10,'normal','center'));
  [4,5,7].forEach(c=>{ws2.getCell(tr2,c).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};});
  setCell(ws2,tr2,6,fmt(ingresos),cellStyle(GOLD,G900,true,13,'normal','center'));
  const nr2=tr2+2;
  const noteCell2=ws2.getCell(nr2,3);
  noteCell2.value='ℹ  Los datos se actualizan automáticamente según el período seleccionado en el panel.';
  noteCell2.font={name:'Calibri',color:{argb:argb(GR3)},size:9,italic:true};
  noteCell2.alignment={horizontal:'left',vertical:'middle'};
  ws2.mergeCells(`C${nr2}:G${nr2}`);
  fillRow(ws2,nr2+2,8,G900);

  // ── Hoja 3: Análisis ──────────────────────────────────────
  const ws3=wb.addWorksheet('Análisis',{views:[{showGridLines:false}]});
  ws3.columns=[{width:1.5},{width:3},{width:22},{width:16},{width:18},{width:16},{width:20},{width:14}];
  const rh3={1:6,2:48,3:8,4:26,5:26,6:24,7:24,8:24,9:24,10:26,11:12,12:26,13:26};
  Object.entries(rh3).forEach(([r,h])=>{ws3.getRow(+r).height=h;});
  for(let r=14;r<=21;r++) ws3.getRow(r).height=22;
  ws3.getRow(21).height=26;
  fillRow(ws3,1,8,G900); fillRow(ws3,2,8,G900);
  setCell(ws3,2,3,'📈  ANÁLISIS DE VENTAS',cellStyle(WHT,G900,true,20,'normal','left'));
  setCell(ws3,4,3,'  ANÁLISIS POR ESTADO',cellStyle(G700,WHT,true,11,'normal','left'));
  ['Estado','Pedidos','Ingresos ($)','% Participación','Ticket Prom.','Tendencia']
    .forEach((h,i)=> setCell(ws3,5,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));
  const tkConf=confirmados>0?ingConf/confirmados:0, tkEntr=entregados>0?ingEntr/entregados:0;
  [['🟡  Pendiente',pendientes,null,pctPend,null,'→  Sin cambios',GR1,ORNG,true],
   ['🔵  Confirmado',confirmados,ingConf,pctConf,tkConf,'↑  En proceso',BLU2,BLU,false],
   ['🟢  Entregado',entregados,ingEntr,pctEntr,tkEntr,'↑  Completado',G100,G500,true],
   ['🔴  Cancelado',cancelados,null,pctCanc,null,'↓  Perdida',RED2,RED,true]]
    .forEach(([lbl,cnt,ing,pct,tk,tend,bg,acc,bld],idx)=>{
      const r=6+idx;
      setCell(ws3,r,3,lbl,cellStyle(acc,bg,bld,10,'normal','left'));
      setCell(ws3,r,4,cnt,cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws3,r,5,ing>0?fmt(Math.round(ing)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws3,r,6,`${pct.toFixed(1)}%`,cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws3,r,7,tk>0?fmt(Math.round(tk)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
      setCell(ws3,r,8,tend,cellStyle(BLK,bg,true,10,'normal','center'));
    });
  const tkAvg=total>0?ingresos/total:0;
  setCell(ws3,10,3,'TOTAL GENERAL',cellStyle(WHT,G900,true,10,'normal','left'));
  setCell(ws3,10,4,String(total),cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,10,5,fmt(Math.round(ingresos)),cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,10,6,'100%',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,10,7,fmt(Math.round(tkAvg)),cellStyle(WHT,G900,true,10,'normal','center'));
  ws3.getCell(10,8).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};
  setCell(ws3,12,3,'  TENDENCIA DIARIA — Últimos 7 días',cellStyle(G700,WHT,true,11,'normal','left'));
  ['Fecha','Pedidos','Ingresos ($)','Ticket Prom.','% vs Anterior']
    .forEach((h,i)=> setCell(ws3,13,3+i,h,cellStyle(WHT,G700,true,10,'normal','center')));
  const daysMap={};
  pedidos.forEach(p=>{
    try{const d=new Date(p.fechaPedido);const key=d.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});
    if(!daysMap[key])daysMap[key]=[];daysMap[key].push(p);}catch(e){}
  });
  const dayAbbr=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  let prevIng=null;
  for(let i=0;i<7;i++){
    const day=new Date(now);day.setDate(now.getDate()-(6-i));
    const r=14+i;
    const key=day.toLocaleDateString('es-CO',{day:'2-digit',month:'2-digit',year:'numeric'});
    const abbr=dayAbbr[(day.getDay()+6)%7];
    const label=`${key} (${abbr})`;
    const peds=daysMap[key]||[], n=peds.length;
    const ingDay=peds.filter(p=>p.estado==='entregado'||p.estado==='confirmado').reduce((s,p)=>s+(p.total||0),0);
    const tkDay=n>0?ingDay/n:0;
    const bg=i%2===0?G50:WHT;
    let varStr='—',varFC=GR3;
    if(prevIng!==null){
      if(prevIng>0){const v=(ingDay-prevIng)/prevIng*100;varStr=(v>=0?'▲':'▼')+` ${Math.abs(v).toFixed(1)}%`;varFC=v>=0?G500:RED;}
      else{varStr='▼ 100.0%';varFC=RED;}
    }
    if(ingDay>0)prevIng=ingDay; else if(prevIng!==null)prevIng=0;
    setCell(ws3,r,3,label,cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,4,n,cellStyle(G700,bg,true,10,'normal','center'));
    setCell(ws3,r,5,ingDay>0?fmt(Math.round(ingDay)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,6,tkDay>0?fmt(Math.round(tkDay)):'—',cellStyle(BLK,bg,false,10,'normal','center'));
    setCell(ws3,r,7,varStr,cellStyle(varFC,bg,true,10,'normal','center'));
  }
  setCell(ws3,21,3,'TOTAL SEMANA',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,21,4,'—',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,21,5,'Dinámico',cellStyle(WHT,G900,true,10,'normal','center'));
  setCell(ws3,21,6,'—',cellStyle(WHT,G900,true,10,'normal','center'));
  [7,8].forEach(c=>{ws3.getCell(21,c).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};});
  fillRow(ws3,36,8,G900);

  // ── Hoja 4: Stock de Productos ────────────────────────────
  if (productos.length > 0) {
    const ws4 = wb.addWorksheet('Stock de Productos', { views:[{showGridLines:false}] });
    ws4.columns = [
      {width:1.5},{width:3},{width:32},{width:18},
      {width:14},{width:18},{width:18},{width:3},
    ];

    const totalP    = productos.length;
    const sinStockN = productos.filter(p=> estadoStock(p.stock||0, p.stockMinimo||STOCK_MIN_DEFAULT)==='sinStock').length;
    const bajosN    = productos.filter(p=> estadoStock(p.stock||0, p.stockMinimo||STOCK_MIN_DEFAULT)==='bajo').length;
    const okN       = totalP - sinStockN - bajosN;
    const valorInv  = productos.reduce((s,p)=>s+((p.stock||0)*(p.precio||p.precioVenta||0)),0);

    const rh4={1:6,2:52,3:9,4:20,5:28,6:28,7:28,8:28,9:10};
    Object.entries(rh4).forEach(([r,h])=>{ws4.getRow(+r).height=h;});
    for(let r=10;r<10+totalP+4;r++) ws4.getRow(r).height=22;
    ws4.getRow(10+totalP).height=28;

    fillRow(ws4,1,8,G900); fillRow(ws4,2,8,G900);
    setCell(ws4,2,3,'📦  STOCK DE PRODUCTOS',    cellStyle(WHT, G900,true, 24,false,'left'));
    setCell(ws4,2,5,'Inventario en tiempo real',  cellStyle(G300,G900,false,11,false,'left'));
    setCell(ws4,2,6,`📅  ${nowStr}`,              cellStyle(G300,G900,false,10,false,'right'));
    setCell(ws4,2,7,`Total: ${totalP} productos`, cellStyle(WHT, G900,true, 11,false,'right'));
    setCell(ws4,4,3,'  RESUMEN DE INVENTARIO',    cellStyle(G700,WHT, true, 11));

    const kpiP=[
      ['📦','TOTAL\nPRODUCTOS',  String(totalP),                                 'en catálogo',     G100, G700    ],
      ['✅','STOCK\nÓPTIMO',     String(okN),                                    'disponibles',     GRN2, '2E7D32'],
      ['⚠️','STOCK\nBAJO',       String(bajosN),                                 'por reabastecer', YLLO, YLLOF   ],
      ['❌','SIN\nSTOCK',        String(sinStockN),                              'agotados',        RED3, RED     ],
      ['💰','VALOR\nINVENTARIO', `$${Number(valorInv).toLocaleString('es-CO')}`, 'estimado',        G100, G700    ],
    ];
    for(let i=0;i<5;i++) ws4.getCell(5,3+i).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(kpiP[i][4])}};
    kpiP.forEach(([em,lbl,val,sub,bg,fc],i)=>{
      setCell(ws4,6,3+i,em, cellStyle(BLK,bg,false,18,false,'center'));
      setCell(ws4,7,3+i,lbl,cellStyle(fc, bg,true,  8,false,'center',true));
      setCell(ws4,8,3+i,val,cellStyle(fc, bg,true, 18,false,'center'));
      setCell(ws4,9,3+i,sub,cellStyle(GR3,bg,false, 8,true, 'center'));
    });

    const HDR=10;
    ['Producto','Categoría','Stock','Estado','Precio']
      .forEach((h,i)=>setCell(ws4,HDR,3+i,h,cellStyle(WHT,G700,true,10,false,'center')));

    const sorted=[...productos].sort((a,b)=>{
      const o=p=>{
        const e=estadoStock(p.stock||0, p.stockMinimo||STOCK_MIN_DEFAULT);
        if(e==='sinStock')return 0; if(e==='bajo')return 1; return 2;
      };
      return o(a)-o(b);
    });

    sorted.forEach((p,idx)=>{
      const r   = HDR+1+idx;
      const s   = p.stock||0;
      const min = p.stockMinimo||STOCK_MIN_DEFAULT;
      const precio = p.precio||p.precioVenta||0;
      const est = estadoStock(s, min);
      let bg, estadoTxt, estadoFC;
      if(est==='sinStock'){bg=RED3; estadoTxt='❌  Sin stock'; estadoFC=RED;}
      else if(est==='bajo'){bg=YLLO;estadoTxt='⚠️  Stock bajo';estadoFC=YLLOF;}
      else                 {bg=GRN2;estadoTxt='✅  Óptimo';    estadoFC='2E7D32';}
      setCell(ws4,r,3,p.nombre||p.name||'—',    cellStyle(BLK,    bg,false,10,false,'left'));
      setCell(ws4,r,4,p.categoria||'—',         cellStyle(GR3,    bg,false,10,false,'center'));
      setCell(ws4,r,5,s,                        cellStyle(estadoFC,bg,true, 12,false,'center'));
      setCell(ws4,r,6,estadoTxt,                cellStyle(estadoFC,bg,true,  9,false,'center'));
      setCell(ws4,r,7,precio>0?fmt(precio):'—', cellStyle(G700,   bg,false,10,false,'center'));
    });

    const trP=HDR+1+sorted.length;
    setCell(ws4,trP,3,'TOTAL PRODUCTOS',                              cellStyle(WHT, G900,true, 10,false,'center'));
    setCell(ws4,trP,5,String(totalP),                                cellStyle(WHT, G900,true, 10,false,'center'));
    setCell(ws4,trP,6,'Valor estimado',                              cellStyle(G300,G900,false, 9,false,'center'));
    setCell(ws4,trP,7,`$${Number(valorInv).toLocaleString('es-CO')}`,cellStyle(GOLD,G900,true, 13,false,'center'));
    [4].forEach(c=>{ws4.getCell(trP,c).fill={type:'pattern',pattern:'solid',fgColor:{argb:argb(G900)}};});

    const nrP=trP+2;
    const noteP=ws4.getCell(nrP,3);
    noteP.value=`ℹ  Stock en tiempo real · Umbral de stock bajo: ${STOCK_MIN_DEFAULT} unidades (o el stockMinimo del producto).`;
    noteP.font={name:'Calibri',color:{argb:argb(GR3)},size:9,italic:true};
    noteP.alignment={horizontal:'left',vertical:'middle'};
    ws4.mergeCells(`C${nrP}:G${nrP}`);
    fillRow(ws4,nrP+2,8,G900);
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

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método no permitido' });
      return;
    }

    (async () => {
      try {
        const { pedidos = [], periodo = 'Este mes', productos = [] } = req.body;
        const xlsxBuf = await generateXlsx(pedidos, periodo, productos);
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

// ═══════════════════════════════════════════════════════════════
//  FUNCIÓN 3: crearAdminUsuario
// ═══════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════
//  FUNCIÓN 4: backupDiario
//  Se ejecuta todos los días a las 12:00am hora Colombia (UTC-5)
//  Guarda un JSON en Firebase Storage con todas las colecciones.
//  Mantiene las últimas 30 copias, borra las más viejas.
// ═══════════════════════════════════════════════════════════════
exports.backupDiario = functions
  .runWith({ memory: '512MB', timeoutSeconds: 300 })
  .pubsub.schedule('0 5 * * *')   // 5:00 AM UTC = 12:00 AM Colombia (UTC-5)
  .timeZone('America/Bogota')
  .onRun(async (context) => {
    const storage = admin.storage().bucket();

    const COLECCIONES = [
      'pedido',
      'productos',
      'usuarios',
      'detalle_pedido',
      'venta',
    ];

    const MAX_BACKUPS = 30;

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

    const datos = {};
    let totalDocs = 0;

    for (const col of COLECCIONES) {
      try {
        const snap = await db.collection(col).get();
        datos[col] = {};
        for (const doc of snap.docs) {
          datos[col][doc.id] = serializar(doc.data());
          totalDocs++;
        }
        console.log(`✅ ${col}: ${snap.size} documentos`);
      } catch (e) {
        console.warn(`⚠️ No se pudo leer ${col}:`, e.message);
        datos[col] = {};
      }
    }

    const ahora   = new Date();
    const fechaStr = ahora.toISOString().replace(/[:.]/g, '-').slice(0, 19);

    const exportFinal = {
      metadata: {
        fecha: ahora.toISOString(),
        version: '1.0',
        tipo: 'automatico',
        colecciones: COLECCIONES,
        totalDocumentos: totalDocs,
      },
      datos,
    };

    const jsonStr = JSON.stringify(exportFinal, null, 2);
    const buffer  = Buffer.from(jsonStr, 'utf8');
    const rutaArchivo = `backups/sistema/backup_${fechaStr}.json`;

    try {
      await storage.file(rutaArchivo).save(buffer, {
        metadata: { contentType: 'application/json' },
      });
      console.log(`✅ Backup guardado: ${rutaArchivo} (${totalDocs} docs, ${(buffer.length / 1024).toFixed(1)} KB)`);
      // Notificar éxito en Firestore
      await db.collection('sistema').doc('ultimoBackup').set({
        fecha:       admin.firestore.Timestamp.fromDate(ahora),
        totalDocs:   totalDocs,
        tamanoKB:    Math.round(buffer.length / 1024),
        rutaArchivo: rutaArchivo,
        exito:       true,
        error:       null,
      });
    } catch (e) {
      console.error('❌ Error guardando backup:', e.message);
      // Notificar fallo en Firestore
      await db.collection('sistema').doc('ultimoBackup').set({
        fecha:       admin.firestore.Timestamp.fromDate(ahora),
        totalDocs:   0,
        tamanoKB:    0,
        rutaArchivo: null,
        exito:       false,
        error:       e.message,
      });
    }

    // Limpiar copias viejas — mantener solo las últimas 30
    try {
      const [archivos] = await storage.getFiles({ prefix: 'backups/sistema/' });
      const soloJson   = archivos.filter(f => f.name.endsWith('.json'));

      if (soloJson.length > MAX_BACKUPS) {
        soloJson.sort((a, b) => a.name.localeCompare(b.name));
        const aEliminar = soloJson.slice(0, soloJson.length - MAX_BACKUPS);
        for (const archivo of aEliminar) {
          await archivo.delete();
          console.log(`🗑️ Eliminado backup viejo: ${archivo.name}`);
        }
      }
    } catch (e) {
      console.warn('⚠️ No se pudo limpiar backups viejos:', e.message);
    }

    return null;
  });