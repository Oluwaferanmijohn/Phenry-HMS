// A small, dependency-free IndexedDB wrapper. Two stores:
//   write_queue     — pending writes made while offline, replayed on reconnect
//   recent_patients — a snapshot of every patient record a user has actually
//                     opened, so reopening it offline works even though
//                     nothing was proactively synced in the background.
//
// This is deliberately NOT a general-purpose sync engine (that's PowerSync's
// job, which we chose not to take on) — it only guarantees two things:
// a write made offline is never lost, and a patient you've already looked
// at stays available offline. Anything never opened while online simply
// isn't there — that tradeoff was made explicitly, not accidentally.

const DB_NAME = 'phenry-health-offline'
const DB_VERSION = 1
export const STORE_QUEUE = 'write_queue'
export const STORE_PATIENTS = 'recent_patients'
const MAX_CACHED_PATIENTS = 60

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB not available in this context'))
      return
    }
    const req = indexedDB.open(DB_NAME, DB_VERSION)
    req.onupgradeneeded = () => {
      const db = req.result
      if (!db.objectStoreNames.contains(STORE_QUEUE)) {
        db.createObjectStore(STORE_QUEUE, { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains(STORE_PATIENTS)) {
        db.createObjectStore(STORE_PATIENTS, { keyPath: 'patientId' })
      }
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

async function withStore<T>(storeName: string, mode: IDBTransactionMode, fn: (store: IDBObjectStore) => IDBRequest): Promise<T> {
  const db = await openDb()
  return new Promise<T>((resolve, reject) => {
    const tx = db.transaction(storeName, mode)
    const store = tx.objectStore(storeName)
    const req = fn(store)
    req.onsuccess = () => resolve(req.result as T)
    req.onerror = () => reject(req.error)
  })
}

export async function idbPut<T>(storeName: string, value: T): Promise<void> {
  await withStore(storeName, 'readwrite', (store) => store.put(value))
}

export async function idbDelete(storeName: string, key: IDBValidKey): Promise<void> {
  await withStore(storeName, 'readwrite', (store) => store.delete(key))
}

export async function idbGetAll<T>(storeName: string): Promise<T[]> {
  return withStore<T[]>(storeName, 'readonly', (store) => store.getAll())
}

export async function idbGet<T>(storeName: string, key: IDBValidKey): Promise<T | undefined> {
  return withStore<T>(storeName, 'readonly', (store) => store.get(key))
}

export interface CachedPatient {
  patientId: string
  cachedAt: number
  data: unknown
}

export async function cachePatientSnapshot(patientId: string, data: unknown) {
  if (typeof indexedDB === 'undefined') return
  try {
    await idbPut<CachedPatient>(STORE_PATIENTS, { patientId, cachedAt: Date.now(), data })
    // Cheap LRU cap so this can't grow forever on a device used for months.
    const all = await idbGetAll<CachedPatient>(STORE_PATIENTS)
    if (all.length > MAX_CACHED_PATIENTS) {
      const oldest = all.sort((a, b) => a.cachedAt - b.cachedAt).slice(0, all.length - MAX_CACHED_PATIENTS)
      await Promise.all(oldest.map((o) => idbDelete(STORE_PATIENTS, o.patientId)))
    }
  } catch {
    // Offline caching is a nice-to-have, not a hard requirement — never
    // let a caching failure break the actual page.
  }
}

export async function getCachedPatientSnapshot<T>(patientId: string): Promise<T | null> {
  if (typeof indexedDB === 'undefined') return null
  try {
    const row = await idbGet<CachedPatient>(STORE_PATIENTS, patientId)
    return (row?.data as T) ?? null
  } catch {
    return null
  }
}
