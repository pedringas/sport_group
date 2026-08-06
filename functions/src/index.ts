import { setGlobalOptions } from "firebase-functions";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { extractMonto } from "./ocr";

admin.initializeApp();
setGlobalOptions({ maxInstances: 10, region: "us-central1" });

const db = admin.firestore();

// OCR en pausa: los comprobantes se aprueban manualmente (admin/tesorero).
// Poner en `true` y redeploy (`firebase deploy --only functions`) para reactivar.
const OCR_ENABLED: boolean = false;

// ─── OCR: validar comprobante ────────────────────────────────────────────────
export const validateComprobante = onObjectFinalized(async (event) => {
  if (!OCR_ENABLED) return;

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

  // SEC-04: verify the pago's owner is still an active member before running OCR
  const grupoId: string = pago.grupoId;
  const miembroSnap = await db
    .collection("grupos").doc(grupoId)
    .collection("miembros").doc(pago.usuarioUid)
    .get();
  if (!miembroSnap.exists || miembroSnap.data()?.estado !== "activo") {
    logger.warn(`Pago ${pagoId}: usuario no es miembro activo, ignorando OCR`);
    return;
  }

  await processComprobanteOcr(pagoId, pagoRef, pago, gsUri, extractMonto);
});

type ExtractFn = typeof extractMonto;
type PagoData = Record<string, unknown>;

// Exported for testing: handles OCR, Firestore update and notifications for a pago
export async function processComprobanteOcr(
  pagoId: string,
  pagoRef: admin.firestore.DocumentReference,
  pago: PagoData,
  gsUri: string,
  extractFn: ExtractFn = extractMonto,
): Promise<void> {
  try {
    // SEC-02: destructure only monto and confianza — raw text is not persisted
    const { monto, confianza } = await extractFn(gsUri);

    const montoEsperado = pago.montoEsperado as number;
    const coincide =
      monto !== null && Math.abs(monto - montoEsperado) <= montoEsperado * 0.05;

    const nuevoEstado = coincide ? "aprobado" : "revision";

    await pagoRef.update({
      montoDetectado: monto,
      ocrConfianza: confianza,
      estado: nuevoEstado,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify member
    await sendNotification({
      usuarioUid: pago.usuarioUid as string,
      title: coincide ? "✅ Pago aprobado" : "⚠️ Pago en revisión",
      body: coincide
        ? `Tu pago de $${montoEsperado} fue validado correctamente.`
        : `Tu comprobante está en revisión manual. El monto detectado fue $${monto ?? "no detectado"}.`,
      data: { tipo: "pago", pagoId, grupoId: pago.grupoId as string },
    });

    // Notify treasurer
    await sendNotificationToRole({
      grupoId: pago.grupoId as string,
      rol: "tesorero",
      title: coincide ? "💰 Nuevo pago aprobado" : "📋 Pago requiere revisión",
      body: `${pago.usuarioNombre as string} ${coincide ? "pagó" : "subió un comprobante que requiere revisión"}.`,
      data: { tipo: "pago_tesorero", pagoId, grupoId: pago.grupoId as string },
    });

    // SEC-07: log state transition only — no financial amounts in logs
    logger.info(`Pago ${pagoId} → ${nuevoEstado}`);
  } catch (err) {
    logger.error("OCR error:", err);
    await pagoRef.update({
      estado: "revision",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// ─── Helpers de notificaciones ───────────────────────────────────────────────

type MessagingClient = { send: (msg: admin.messaging.Message) => Promise<string> };
type NotifyArgs = { usuarioUid: string; title: string; body: string; data: Record<string, string> };
type NotifyFn = (args: NotifyArgs) => Promise<void>;

// Exported for testing
export async function sendNotification(
  { usuarioUid, title, body, data }: NotifyArgs,
  fsDb: admin.firestore.Firestore = db,
  messaging: MessagingClient = admin.messaging(),
): Promise<void> {
  const userSnap = await fsDb.collection("usuarios").doc(usuarioUid).get();
  const token = userSnap.data()?.fcmToken;
  if (!token) return;

  await messaging.send({
    token,
    notification: { title, body },
    data,
    android: { priority: "high" },
  });
}

// Exported for testing
export async function sendNotificationToRole(
  { grupoId, rol, title, body, data }: {
    grupoId: string;
    rol: string;
    title: string;
    body: string;
    data: Record<string, string>;
  },
  fsDb: admin.firestore.Firestore = db,
  notifyFn: NotifyFn = (args) => sendNotification(args),
): Promise<void> {
  const miembrosSnap = await fsDb
    .collection("grupos")
    .doc(grupoId)
    .collection("miembros")
    .where("rol", "==", rol)
    .where("estado", "==", "activo")
    .get();

  const uids = miembrosSnap.docs.map((d) => d.id);
  for (const uid of uids) {
    await notifyFn({ usuarioUid: uid, title, body, data });
  }
}
