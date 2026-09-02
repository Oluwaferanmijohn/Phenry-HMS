// Encrypted, user-scoped browser persistence for the deliberately small
// offline surface: durable structured writes and recently opened patients.
// Version 2 intentionally destroys the old plaintext stores during upgrade.

const DB_NAME = 'phenry-health-offline'
const DB_VERSION = 2
const STORE_QUEUE = 'write_queue'
const STORE_PATIENTS = 'recent_patients'
const STORE_KEYS = 'encryption_keys'
const MAX_CACHED_PATIENTS = 60
const MAX_CACHE_AGE_MS = 7 * 24 * 60 * 60 * 1000

interface EncryptedEnvelope {
  storageKey: string
  ownerUserId: string
  iv: string
  ciphertext: string
  updatedAt: number
  version: 2
}

interface KeyRecord {
  userId: string
  key: CryptoKey
}

export interface DurableQueuedWrite<T = unknown> {
  id: string
  label: string
  ops: T
  createdAt: number
  attempts?: number
  lastError?: string
}

interface CachedPatient<T = unknown> {
  patientId: string
  cachedAt: number
  data: T
}

let dbPromise: Promise<IDBDatabase> | null = null

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise
  dbPromise = new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined' || !globalThis.crypto?.subtle) {
      reject(new Error('Secure browser storage is unavailable'))
      return
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION)
    request.onupgradeneeded = () => {
      const db = request.result
      // v1 held PHI and queue payloads as plaintext. Never migrate it.
      for (const store of [STORE_QUEUE, STORE_PATIENTS, STORE_KEYS]) {
        if (db.objectStoreNames.contains(store)) db.deleteObjectStore(store)
      }
      const queue = db.createObjectStore(STORE_QUEUE, { keyPath: 'storageKey' })
      queue.createIndex('ownerUserId', 'ownerUserId', { unique: false })
      const patients = db.createObjectStore(STORE_PATIENTS, { keyPath: 'storageKey' })
      patients.createIndex('ownerUserId', 'ownerUserId', { unique: false })
      db.createObjectStore(STORE_KEYS, { keyPath: 'userId' })
    }
    request.onsuccess = () => {
      request.result.onversionchange = () => request.result.close()
      resolve(request.result)
    }
    request.onerror = () => {
      dbPromise = null
      reject(request.error || new Error('Could not open secure browser storage'))
    }
    request.onblocked = () => {
      dbPromise = null
      reject(new Error('Secure browser storage upgrade is blocked by another tab'))
    }
  })
  return dbPromise
}

async function requestResult<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function getRecord<T>(storeName: string, key: IDBValidKey): Promise<T | undefined> {
  const db = await openDb()
  const tx = db.transaction(storeName, 'readonly')
  return requestResult<T | undefined>(tx.objectStore(storeName).get(key))
}

async function getAllByOwner(storeName: string, userId: string): Promise<EncryptedEnvelope[]> {
  const db = await openDb()
  const tx = db.transaction(storeName, 'readonly')
  return requestResult<EncryptedEnvelope[]>(tx.objectStore(storeName).index('ownerUserId').getAll(userId))
}

async function putRecord<T>(storeName: string, value: T): Promise<void> {
  const db = await openDb()
  const tx = db.transaction(storeName, 'readwrite')
  await requestResult(tx.objectStore(storeName).put(value))
}

async function deleteRecord(storeName: string, key: IDBValidKey): Promise<void> {
  const db = await openDb()
  const tx = db.transaction(storeName, 'readwrite')
  await requestResult(tx.objectStore(storeName).delete(key))
}

async function encryptionKey(userId: string): Promise<CryptoKey> {
  const existing = await getRecord<KeyRecord>(STORE_KEYS, userId)
  if (existing?.key) return existing.key
  const key = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt'])
  await putRecord<KeyRecord>(STORE_KEYS, { userId, key })
  return key
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  }
  return btoa(binary)
}

function base64ToBytes(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value)
  const bytes = new Uint8Array(new ArrayBuffer(binary.length))
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

async function patientStorageKey(userId: string, patientId: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${userId}:${patientId}`))
  return `patient:${bytesToBase64(new Uint8Array(digest)).replace(/[+/=]/g, '_')}`
}

function queueStorageKey(userId: string, queueId: string) {
  return `queue:${userId}:${queueId}`
}

async function encrypt<T>(userId: string, storageKey: string, purpose: string, value: T): Promise<EncryptedEnvelope> {
  const key = await encryptionKey(userId)
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const additionalData = new TextEncoder().encode(`${userId}:${purpose}:${storageKey}`)
  const plaintext = new TextEncoder().encode(JSON.stringify(value))
  const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData }, key, plaintext)
  return {
    storageKey,
    ownerUserId: userId,
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(new Uint8Array(ciphertext)),
    updatedAt: Date.now(),
    version: 2,
  }
}

async function decrypt<T>(envelope: EncryptedEnvelope, userId: string, purpose: string): Promise<T> {
  if (envelope.version !== 2 || envelope.ownerUserId !== userId) throw new Error('Offline record ownership mismatch')
  const key = await encryptionKey(userId)
  const additionalData = new TextEncoder().encode(`${userId}:${purpose}:${envelope.storageKey}`)
  const plaintext = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: base64ToBytes(envelope.iv), additionalData },
    key,
    base64ToBytes(envelope.ciphertext),
  )
  return JSON.parse(new TextDecoder().decode(plaintext)) as T
}

export async function saveQueuedWrite<T>(userId: string, write: DurableQueuedWrite<T>): Promise<void> {
  const storageKey = queueStorageKey(userId, write.id)
  await putRecord(STORE_QUEUE, await encrypt(userId, storageKey, 'queue', write))
}

export async function loadQueuedWrites<T>(userId: string): Promise<DurableQueuedWrite<T>[]> {
  const rows = await getAllByOwner(STORE_QUEUE, userId)
  const writes: DurableQueuedWrite<T>[] = []
  for (const row of rows) {
    try {
      writes.push(await decrypt<DurableQueuedWrite<T>>(row, userId, 'queue'))
    } catch {
      // Corrupt/undecryptable PHI should not linger or retry forever.
      await deleteRecord(STORE_QUEUE, row.storageKey)
    }
  }
  return writes.sort((a, b) => a.createdAt - b.createdAt)
}

export async function deleteQueuedWrite(userId: string, queueId: string): Promise<void> {
  await deleteRecord(STORE_QUEUE, queueStorageKey(userId, queueId))
}

export async function cachePatientSnapshot(userId: string, patientId: string, data: unknown): Promise<void> {
  const storageKey = await patientStorageKey(userId, patientId)
  const value: CachedPatient = { patientId, cachedAt: Date.now(), data }
  await putRecord(STORE_PATIENTS, await encrypt(userId, storageKey, 'patient', value))

  const rows = await getAllByOwner(STORE_PATIENTS, userId)
  if (rows.length <= MAX_CACHED_PATIENTS) return
  const oldest = rows.sort((a, b) => a.updatedAt - b.updatedAt).slice(0, rows.length - MAX_CACHED_PATIENTS)
  await Promise.all(oldest.map((row) => deleteRecord(STORE_PATIENTS, row.storageKey)))
}

export async function getCachedPatientSnapshot<T>(userId: string, patientId: string): Promise<T | null> {
  const storageKey = await patientStorageKey(userId, patientId)
  const row = await getRecord<EncryptedEnvelope>(STORE_PATIENTS, storageKey)
  if (!row || row.ownerUserId !== userId) return null
  try {
    const cached = await decrypt<CachedPatient<T>>(row, userId, 'patient')
    if (Date.now() - cached.cachedAt > MAX_CACHE_AGE_MS) {
      await deleteRecord(STORE_PATIENTS, storageKey)
      return null
    }
    return cached.data
  } catch {
    await deleteRecord(STORE_PATIENTS, storageKey)
    return null
  }
}

export async function clearOfflineData(userId: string): Promise<void> {
  try {
    const [queue, patients] = await Promise.all([
      getAllByOwner(STORE_QUEUE, userId),
      getAllByOwner(STORE_PATIENTS, userId),
    ])
    await Promise.all([
      ...queue.map((row) => deleteRecord(STORE_QUEUE, row.storageKey)),
      ...patients.map((row) => deleteRecord(STORE_PATIENTS, row.storageKey)),
    ])
    await deleteRecord(STORE_KEYS, userId)
  } catch {
    // Storage may already have been cleared by the browser or be unavailable.
  }
}
