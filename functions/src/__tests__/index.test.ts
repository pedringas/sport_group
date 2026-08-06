// TEST-04: validateComprobante — Vision API failure falls back to 'revision'

jest.mock('firebase-admin', () => {
  const mockFieldValue = { serverTimestamp: jest.fn(() => 'SERVER_TS') };
  const mockFirestore = Object.assign(jest.fn(() => ({})), { FieldValue: mockFieldValue });
  return {
    initializeApp: jest.fn(),
    apps: [{}],
    firestore: mockFirestore,
    messaging: jest.fn(() => ({ send: jest.fn() })),
  };
});

jest.mock('firebase-functions', () => ({ setGlobalOptions: jest.fn() }));
jest.mock('firebase-functions/v2/storage', () => ({ onObjectFinalized: jest.fn() }));
jest.mock('firebase-functions/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

import * as admin from 'firebase-admin';
import { processComprobanteOcr } from '../index';

describe('processComprobanteOcr', () => {
  const pagoData = {
    grupoId: 'g1',
    usuarioUid: 'u1',
    usuarioNombre: 'Ana García',
    montoEsperado: 500,
  };

  let mockUpdate: jest.Mock;
  let mockRef: admin.firestore.DocumentReference;

  beforeEach(() => {
    mockUpdate = jest.fn().mockResolvedValue(undefined);
    mockRef = { id: 'pago123', update: mockUpdate } as unknown as admin.firestore.DocumentReference;
  });

  test('sets estado to revision when Vision API throws', async () => {
    const failExtract = jest.fn().mockRejectedValue(new Error('Vision API unavailable'));

    await processComprobanteOcr('pago123', mockRef, pagoData, 'gs://bucket/path.jpg', failExtract);

    expect(mockUpdate).toHaveBeenCalledTimes(1);
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'revision' }),
    );
  });

  test('does not re-throw when Vision API fails', async () => {
    const failExtract = jest.fn().mockRejectedValue(new Error('quota exceeded'));

    await expect(
      processComprobanteOcr('pago123', mockRef, pagoData, 'gs://bucket/path.jpg', failExtract),
    ).resolves.toBeUndefined();
  });

  test('sets estado to aprobado when monto matches within 5%', async () => {
    const mockExtract = jest.fn().mockResolvedValue({ monto: 502, confianza: 0.85 });
    // Mock sendNotification dependencies — db.collection is not real; skip notification path
    // by using a no-op for any notification call.
    // The update call is the assertion of interest here.
    try {
      await processComprobanteOcr('pago123', mockRef, pagoData, 'gs://bucket/path.jpg', mockExtract);
    } catch {
      // sendNotification may fail in unit test — only assert the update
    }

    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'aprobado', montoDetectado: 502 }),
    );
  });

  test('sets estado to revision when monto differs by more than 5%', async () => {
    const mockExtract = jest.fn().mockResolvedValue({ monto: 300, confianza: 0.85 });
    try {
      await processComprobanteOcr('pago123', mockRef, pagoData, 'gs://bucket/path.jpg', mockExtract);
    } catch {
      // sendNotification may fail in unit test — only assert the update
    }

    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'revision', montoDetectado: 300 }),
    );
  });

  test('sets estado to revision when monto is null (no amount detected)', async () => {
    const mockExtract = jest.fn().mockResolvedValue({ monto: null, confianza: 0 });
    try {
      await processComprobanteOcr('pago123', mockRef, pagoData, 'gs://bucket/path.jpg', mockExtract);
    } catch {
      // sendNotification may fail in unit test — only assert the update
    }

    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'revision' }),
    );
  });
});
