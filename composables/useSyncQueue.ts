import { computed, reactive } from 'vue'
import { useToast } from '~/composables/useToast'
import {
  clearOfflineData,
  deleteQueuedWrite,
  loadQueuedWrites,
  saveQueuedWrite,
  type DurableQueuedWrite,
} from '~/composables/useOfflineDb'

export type WriteOp =
  | { table: string; kind: 'insert'; payload: Record<string, any> }
  | { table: string; kind: 'update'; payload: Record<string, any>; match: Record<string, any>; expectedUpdatedAt?: string }
  | { table: string; kind: 'upsert'; payload: Record<string, any> | Record<string, any>[]; onConflict?: string }
  | { table: string; kind: 'delete'; match: Record<string, any>; expectedUpdatedAt?: string }
  | { kind: 'rpc'; rpcName: string; payload?: Record<string, any> }

interface QueuedWrite extends DurableQueuedWrite<WriteOp[]> {
  onSuccess?: () => void
}

const state = reactive<{
  online: boolean
  queue: QueuedWrite[]
  hydratedFor: string | null
  flushing: boolean
}>({
  online: import.meta.client ? navigator.onLine : false,
  queue: [],
  hydratedFor: null,
  flushing: false,
})

function errorMessage(error: unknown): string {
  if (error && typeof error === 'object' && 'message' in error) return String(error.message).slice(0, 300)
  return 'Unknown synchronization error'
}

async function runOp(supabase: any, op: WriteOp) {
  if (op.kind === 'insert') {
    const { error } = await supabase.from(op.table).insert(op.payload)
    if (error) throw error
    return
  }

  if (op.kind === 'update') {
    let query = supabase.from(op.table).update(op.payload)
    for (const [key, value] of Object.entries(op.match)) query = query.eq(key, value)
    if (op.expectedUpdatedAt) query = query.eq('updated_at', op.expectedUpdatedAt)
    // Not every table uses an `id` primary key. bio_details, for example,
    // is keyed by patient_id. Select a column we know exists because it was
    // already used in the match instead of assuming a universal schema.
    const returnColumn = Object.keys(op.match)[0] || '*'
    const { data, error } = await query.select(returnColumn)
    if (error) throw error
    if (op.expectedUpdatedAt && (!data || data.length === 0)) {
      throw new Error(`Conflict: ${op.table} changed on the server while this device was offline`)
    }
    return
  }

  if (op.kind === 'upsert') {
    const { error } = await supabase
      .from(op.table)
      .upsert(op.payload, op.onConflict ? { onConflict: op.onConflict } : undefined)
    if (error) throw error
    return
  }

  if (op.kind === 'delete') {
    let query = supabase.from(op.table).delete()
    for (const [key, value] of Object.entries(op.match)) query = query.eq(key, value)
    if (op.expectedUpdatedAt) query = query.eq('updated_at', op.expectedUpdatedAt)
    const returnColumn = Object.keys(op.match)[0] || '*'
    const { data, error } = await query.select(returnColumn)
    if (error) throw error
    if (op.expectedUpdatedAt && (!data || data.length === 0)) {
      throw new Error(`Conflict: ${op.table} changed on the server while this device was offline`)
    }
    return
  }

  const { error } = await supabase.rpc(op.rpcName, op.payload || {})
  if (error) throw error
}

export function useSyncQueue() {
  const { toast } = useToast()
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  async function hydrate(userId = user.value?.id) {
    if (!userId) {
      state.queue = []
      state.hydratedFor = null
      return
    }
    if (state.hydratedFor !== userId) {
      state.queue = []
      try {
        state.queue = await loadQueuedWrites<WriteOp[]>(userId)
      } catch {
        toast('Secure offline storage is unavailable; offline changes cannot survive a refresh', 'warn')
      }
      state.hydratedFor = userId
    }
    if (state.online && state.queue.length) await flushQueue()
  }

  async function runQueuedWrite(item: QueuedWrite) {
    for (const op of item.ops) await runOp(supabase, op)
    item.onSuccess?.()
  }

  async function queueOrRun(
    label: string,
    opsOrRun: WriteOp | WriteOp[] | (() => Promise<void> | void),
    onSuccess?: () => void,
  ) {
    // Keep accepting durable offline writes if Supabase's reactive user is
    // temporarily null during a failed token refresh. `hydratedFor` is the
    // already-confirmed owner of this encrypted queue and is never borrowed
    // while online.
    const userId = user.value?.id || (!state.online ? state.hydratedFor || undefined : undefined)
    if (!userId) throw new Error('You must be signed in to save changes')
    if (state.hydratedFor !== userId) await hydrate(userId)

    const isClosure = typeof opsOrRun === 'function'
    if (state.online) {
      try {
        if (isClosure) await opsOrRun()
        else for (const op of Array.isArray(opsOrRun) ? opsOrRun : [opsOrRun]) await runOp(supabase, op)
        onSuccess?.()
        toast(label, 'success')
        return
      } catch (error) {
        toast(errorMessage(error), 'warn')
        throw error
      }
    }

    // JavaScript closures cannot be serialized safely. Refuse them offline
    // instead of claiming they were saved and silently losing them on reload.
    if (isClosure) {
      const error = new Error('This action needs a connection and was not saved')
      toast(error.message, 'warn')
      throw error
    }

    const item: QueuedWrite = {
      id: crypto.randomUUID(),
      label,
      ops: Array.isArray(opsOrRun) ? opsOrRun : [opsOrRun],
      createdAt: Date.now(),
      attempts: 0,
      onSuccess,
    }
    state.queue.push(item)
    try {
      await saveQueuedWrite(userId, {
        id: item.id,
        label: item.label,
        ops: item.ops,
        createdAt: item.createdAt,
        attempts: 0,
      })
      toast(`Encrypted locally — ${state.queue.length} change${state.queue.length === 1 ? '' : 's'} pending`, 'warn')
    } catch (error) {
      toast('Kept in this tab only; secure offline storage is unavailable', 'warn')
    }
  }

  async function flushQueue() {
    const userId = user.value?.id
    if (!state.online || !userId || state.flushing || state.hydratedFor !== userId || !state.queue.length) return
    state.flushing = true
    let synced = 0
    let failed = 0
    try {
      for (const item of [...state.queue].sort((a, b) => a.createdAt - b.createdAt)) {
        if (!state.online || user.value?.id !== userId) break
        try {
          await runQueuedWrite(item)
          state.queue = state.queue.filter((queued) => queued.id !== item.id)
          await deleteQueuedWrite(userId, item.id)
          synced++
        } catch (error) {
          item.attempts = (item.attempts || 0) + 1
          item.lastError = errorMessage(error)
          failed++
          try {
            await saveQueuedWrite(userId, {
              id: item.id,
              label: item.label,
              ops: item.ops,
              createdAt: item.createdAt,
              attempts: item.attempts,
              lastError: item.lastError,
            })
          } catch {
            // Keep the in-memory copy; the original encrypted copy remains.
          }
        }
      }
    } finally {
      state.flushing = false
    }
    if (synced) toast(`Synced ${synced} pending change${synced === 1 ? '' : 's'}`, 'success')
    if (failed) toast(`${failed} change${failed === 1 ? '' : 's'} needs review before it can sync`, 'warn')
  }

  function setOnline(value: boolean) {
    const changed = state.online !== value
    state.online = value
    if (value) void flushQueue()
    else if (changed) toast('You are offline — supported changes will be encrypted on this device', 'warn')
  }

  async function clearUserState(userId: string) {
    if (state.hydratedFor === userId) {
      state.queue = []
      state.hydratedFor = null
    }
    await clearOfflineData(userId)
  }

  return {
    online: computed(() => state.online),
    pendingCount: computed(() => state.queue.length),
    pendingChanges: computed(() => state.queue.map(({ id, label, createdAt, attempts, lastError }) => ({ id, label, createdAt, attempts, lastError }))),
    flushing: computed(() => state.flushing),
    queueOrRun,
    flushQueue,
    setOnline,
    hydrate,
    clearUserState,
  }
}
