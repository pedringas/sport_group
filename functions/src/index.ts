import { setGlobalOptions } from "firebase-functions";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { extractMonto } from "./ocr";

admin.initializeApp();
setGlobalOptions({ maxInstances: 10, region: "us-central1" });

const db = admin.firestore();

// ─── OCR: validar comprobante ────────────────────────────────────────────────
export const validateComprobante = onObjectFinalized(async (event) => {
  const filePath = event.data.name ?? "";

  // Only process comprobantes: grupos/{grupoId}/comprobantes/{pagoId}.jpg
  const match = filePath.match(/^grupos\/([^/]+)\/comprobantes\/([^/]+)\.jpg$/);
  if (!match) return;

  const pagoId = match[2];
  const bucket = event.data.bucket;
  const gsUri = `gs://${bucket}/${filePath}`;

  logger.info(`Processing comprobante for pago ${pagoId}`);

  const pagoRef = db.collection("pagos").doc(pagoId);
  const pagoSnap = await pagoRef.get();
  if (!pagoSnap.exists) return;

  const pago = pagoSnap.data()!;

  try {
    const { monto, raw, confianza } = await extractMonto(gsUri);

    const montoEsperado: number = pago.montoEsperado;
    const coincide =
      monto !== null && Math.abs(monto - montoEsperado) <= montoEsperado * 0.05;

    const nuevoEstado = coincide ? "aprobado" : "revision";

    await pagoRef.update({
      montoDetectado: monto,
      ocrRaw: raw,
      ocrConfianza: confianza,
      estado: nuevoEstado,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify member
    await sendNotification({
      usuarioUid: pago.usuarioUid,
      title: coincide ? "✅ Pago aprobado" : "⚠️ Pago en revisión",
      body: coincide
        ? `Tu pago de $${montoEsperado} fue validado correctamente.`
        : `Tu comprobante está en revisión manual. El monto detectado fue $${monto ?? "no detectado"}.`,
      data: { tipo: "pago", pagoId, grupoId: pago.grupoId },
    });

    // Notify treasurer
    await sendNotificationToRole({
      grupoId: pago.grupoId,
      rol: "tesorero",
      title: coincide ? "💰 Nuevo pago aprobado" : "📋 Pago requiere revisión",
      body: `${pago.usuarioNombre} ${coincide ? "pagó" : "subió un comprobante que requiere revisión"}.`,
      data: { tipo: "pago_tesorero", pagoId, grupoId: pago.grupoId },
    });

    logger.info(`Pago ${pagoId} → ${nuevoEstado} (detectado: ${monto})`);
  } catch (err) {
    logger.error("OCR error:", err);
    await pagoRef.update({
      estado: "revision",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

// ─── Helpers de notificaciones ───────────────────────────────────────────────
async function sendNotification({
  usuarioUid,
  title,
  body,
  data,
}: {
  usuarioUid: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const userSnap = await db.collection("usuarios").doc(usuarioUid).get();
  const token = userSnap.data()?.fcmToken;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: { title, body },
    data,
    android: { priority: "high" },
  });
}

async function sendNotificationToRole({
  grupoId,
  rol,
  title,
  body,
  data,
}: {
  grupoId: string;
  rol: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const miembrosSnap = await db
    .collection("grupos")
    .doc(grupoId)
    .collection("miembros")
    .where("rol", "==", rol)
    .where("estado", "==", "activo")
    .get();

  const uids = miembrosSnap.docs.map((d) => d.id);
  for (const uid of uids) {
    await sendNotification({ usuarioUid: uid, title, body, data });
  }
}
