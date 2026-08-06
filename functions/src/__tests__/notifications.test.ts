// TEST-07: sendNotificationToRole and sendNotification unit tests

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

import { sendNotification, sendNotificationToRole } from '../index';
import type * as admin from 'firebase-admin';

// ── Firestore mock builders ────────────────────────────────────────────────────

function makeDb(options: {
  memberUids?: string[];
  userTokens?: Record<string, string | null>;
}): admin.firestore.Firestore {
  const { memberUids = [], userTokens = {} } = options;

  const memberDocs = memberUids.map((id) => ({ id }));

  const membersQuery = {
    where: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({ docs: memberDocs }),
  };

  const membersCollection = {
    where: jest.fn().mockReturnThis(),
    get: membersQuery.get,
  };

  const gruposDoc = {
    collection: jest.fn(() => membersCollection),
  };

  const usuariosDoc = jest.fn((uid: string) => ({
    get: jest.fn().mockResolvedValue({
      data: () => ({ fcmToken: userTokens[uid] ?? null }),
    }),
  }));

  const db = {
    collection: jest.fn((name: string) => {
      if (name === "grupos") {
        return { doc: jest.fn(() => gruposDoc) };
      }
      if (name === "usuarios") {
        return { doc: usuariosDoc };
      }
      return {};
    }),
  } as unknown as admin.firestore.Firestore;

  return db;
}

// ── sendNotificationToRole ────────────────────────────────────────────────────

describe('sendNotificationToRole', () => {
  const roleArgs = {
    grupoId: 'g1',
    rol: 'tesorero',
    title: '📋 Nuevo pago',
    body: 'Ana pagó $500',
    data: { tipo: 'pago', pagoId: 'p1', grupoId: 'g1' },
  };

  test('no members with role → notifyFn is never called', async () => {
    const mockDb = makeDb({ memberUids: [] });
    const mockNotify = jest.fn();

    await sendNotificationToRole(roleArgs, mockDb, mockNotify);

    expect(mockNotify).not.toHaveBeenCalled();
  });

  test('one member → notifyFn called once with correct uid', async () => {
    const mockDb = makeDb({ memberUids: ['u1'] });
    const mockNotify = jest.fn().mockResolvedValue(undefined);

    await sendNotificationToRole(roleArgs, mockDb, mockNotify);

    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(mockNotify).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioUid: 'u1', title: roleArgs.title }),
    );
  });

  test('two members → notifyFn called twice with correct uids', async () => {
    const mockDb = makeDb({ memberUids: ['u1', 'u2'] });
    const mockNotify = jest.fn().mockResolvedValue(undefined);

    await sendNotificationToRole(roleArgs, mockDb, mockNotify);

    expect(mockNotify).toHaveBeenCalledTimes(2);
    const uids = mockNotify.mock.calls.map((c) => c[0].usuarioUid);
    expect(uids).toContain('u1');
    expect(uids).toContain('u2');
  });

  test('passes title, body and data through to notifyFn', async () => {
    const mockDb = makeDb({ memberUids: ['u1'] });
    const mockNotify = jest.fn().mockResolvedValue(undefined);

    await sendNotificationToRole(roleArgs, mockDb, mockNotify);

    expect(mockNotify).toHaveBeenCalledWith(
      expect.objectContaining({
        title: roleArgs.title,
        body: roleArgs.body,
        data: roleArgs.data,
      }),
    );
  });
});

// ── sendNotification ──────────────────────────────────────────────────────────

describe('sendNotification', () => {
  const notifArgs = {
    usuarioUid: 'u1',
    title: '✅ Pago aprobado',
    body: 'Tu pago fue validado',
    data: { tipo: 'pago', pagoId: 'p1', grupoId: 'g1' },
  };

  test('sends FCM message when user has token', async () => {
    const mockSend = jest.fn().mockResolvedValue('msg-id');
    const mockDb = makeDb({ userTokens: { u1: 'device-token-abc' } });

    await sendNotification(notifArgs, mockDb, { send: mockSend });

    expect(mockSend).toHaveBeenCalledTimes(1);
    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        token: 'device-token-abc',
        notification: { title: notifArgs.title, body: notifArgs.body },
      }),
    );
  });

  test('skips FCM when user has no token', async () => {
    const mockSend = jest.fn();
    const mockDb = makeDb({ userTokens: { u1: null } });

    await sendNotification(notifArgs, mockDb, { send: mockSend });

    expect(mockSend).not.toHaveBeenCalled();
  });

  test('skips FCM when user document has no fcmToken field', async () => {
    const mockSend = jest.fn();
    const mockDb = makeDb({ userTokens: {} }); // u1 not in map → null

    await sendNotification(notifArgs, mockDb, { send: mockSend });

    expect(mockSend).not.toHaveBeenCalled();
  });

  test('passes android high-priority flag', async () => {
    const mockSend = jest.fn().mockResolvedValue('msg-id');
    const mockDb = makeDb({ userTokens: { u1: 'token-xyz' } });

    await sendNotification(notifArgs, mockDb, { send: mockSend });

    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({ android: { priority: 'high' } }),
    );
  });
});
