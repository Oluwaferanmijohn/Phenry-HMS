import { reactive, computed } from 'vue'
import { useToast } from '~/composables/useToast'
import { idbPut, idbDelete, idbGetAll, STORE_QUEUE } from '~/composables/useOfflineDb'

// Three things can be passed to queueOrRun now, on purpose:
//
//  - `ops` (WriteOp[])   — data, not a function. Persisted to IndexedDB, so
//                          a write made offline survives a hard refresh or
//                          the app/tab being killed while still offline.
//                          Prefer this for any call site that just needs
//                          the DB write itself to be durable.
//  - `onSuccess`         — an optional callback that runs right after the
//                          write actually succeeds (immediately if online,
//                          or when the queue flushes on reconnect). Used
//                          for local optimistic UI updates or a manual
//                          refetch that isn't itself a DB write. This is
//                          NOT persisted — if the app is refreshed while a
//                          write is still queued, the in-memory state it
//                          would have updated doesn't exist any more
//                          either, so there's nothing lost. Once the write
//                          actually lands, the app-wide Realtime
//                          subscription (plugins/realtime.client.ts) picks
//                          up the DB change and refreshes the current
//                          page's data anyway.
//  - `run` (closure)     — the original in-memory-only form every
//                          pre-existing call site in this codebase used
//                          before this file was updated. Kept working
//                          exactly as before (queued, flushed on
//                          reconnect); same limitation as before this
//                          change — lost if the app is refreshed/killed
//                          while still offline, since a closure can't be
//                          saved to IndexedDB.
export type WriteOp =
  | { table: string; kind: 'insert'; payload: Record<string, any> }
  | { table: string; kind: 'update'; payload: Record<string, any>; match: Record<string, any> }
  | { table: string; kind: 'upsert'; payload: Record<string, any> | Record<string, any>[]; onConflict?: string }
  | { table: string; kind: 'delete'; match: Record<string, any> }
  | { kind: 'rpc'; rpcName: string; payload?: Record<string, any> }

interface QueuedWrite {
  id: string
  label: string
  ops?: WriteOp[] // present <=> persisted to IndexedDB (durable form)
  run?: () => Promise<void> | void // present <=> legacy in-memory-only form
  onSuccess?: () => void // in-memory only, either form — see comment above
  createdAt: number
}

const state = reactive<{ online: boolean; queue: QueuedWrite[]; hydrated: boolean }>({
  online: true, // plugins/sync.client.ts corrects this to navigator.onLine on mount
  queue: [],
  hydrated: false,
})

async function runOp(supabase: any, op: WriteOp) {
  if (op.kind === 'insert') {
    const { error } = await supabase.from(op.table).insert(op.payload)
    if (error) throw error
  } else if (op.kind === 'update') {
    let q = supabase.from(op.table).update(op.payload)
    for (const [k, v] of Object.entries(op.match)) q = q.eq(k, v)
    const { error } = await q
    if (error) throw error
  } else if (op.kind === 'upsert') {
    const { error } = await supabase.from(op.table).upsert(op.payload, op.onConflict ? { onConflict: op.onConflict } : undefined)
    if (error) throw error
  } else if (op.kind === 'delete') {
    let q = supabase.from(op.table).delete()
    for (const [k, v] of Object.entries(op.match)) q = q.eq(k, v)
    const { error } = await q
    if (error) throw error
  } else if (op.kind === 'rpc') {
    const { error } = await supabase.rpc(op.rpcName, op.payload || {})
    if (error) throw error
  }
}

export function useSyncQueue() {
  const { toast } = useToast()
  const supabase = useSupabaseClient()

  // Restores whatever was still pending from a previous session. Only `ops`
  // (durable) entries can be restored this way — see the QueuedWrite
  // comment above. Called once by plugins/sync.client.ts on app boot, safe
  // to call again (no-op after the first successful hydration).
  async function hydrate() {
    if (state.hydrated) return
    state.hydrated = true
    try {
      const saved = await idbGetAll<QueuedWrite>(STORE_QUEUE)
      state.queue.push(...saved.sort((a, b) => a.createdAt - b.createdAt))
    } catch {
      // IndexedDB unavailable (very old browser, private-mode edge cases) —
      // degrade to in-memory-only, same as before this change.
    }
  }

  async function runQueuedWrite(item: QueuedWrite) {
    if (item.ops) {
      for (const op of item.ops) await runOp(supabase, op)
    } else if (item.run) {
      await item.run()
    }
    item.onSuccess?.()
  }

  // Accepts either the new durable form (a WriteOp or WriteOp[], optionally
  // with an onSuccess callback for local UI state) or the original closure
  // form that pre-existing call sites pass.
  async function queueOrRun(
    label: string,
    opsOrRun: WriteOp | WriteOp[] | (() => Promise<void> | void),
    onSuccess?: () => void
  ) {
    const isClosure = typeof opsOrRun === 'function'
    const ops = isClosure ? undefined : (Array.isArray(opsOrRun) ? opsOrRun : [opsOrRun])

    if (state.online) {
      try {
        if (isClosure) await opsOrRun()
        else for (const op of ops!) await runOp(supabase, op)
        onSuccess?.()
        toast(label, 'success')
      } catch (err) {
        toast('Something went wrong — please try again', 'warn')
        throw err
      }
    } else {
      const item: QueuedWrite = {
        id: crypto.randomUUID(),
        label,
        createdAt: Date.now(),
        onSuccess,
        ...(isClosure ? { run: opsOrRun as () => Promise<void> | void } : { ops }),
      }
      state.queue.push(item)
      if (item.ops) {
        try {
          // onSuccess is deliberately not included — it can't be
          // serialized, and isn't needed after a real refresh (see the
          // QueuedWrite comment above).
          await idbPut(STORE_QUEUE, { id: item.id, label: item.label, ops: item.ops, createdAt: item.createdAt })
        } catch {
          // Still held in memory even if the IndexedDB write fails — better
          // than silently dropping it, though it won't survive a hard refresh.
        }
      }
      toast(`Saved locally — will sync when back online (${state.queue.length} pending)`, 'warn')
    }
  }

  async function flushQueue() {
    if (!state.queue.length) return
    const pending = [...state.queue]
    state.queue.length = 0
    let synced = 0
    let failed = 0

    for (const item of pending) {
      try {
        await runQueuedWrite(item)
        if (item.ops) await idbDelete(STORE_QUEUE, item.id)
        synced++
      } catch {
        // Genuinely failed even though we're back online — e.g. an
        // appointment slot got taken by someone else while this was
        // queued. Keep it queued but surface it distinctly rather than
        // silently retrying forever.
        state.queue.push(item)
        failed++
      }
    }

    if (synced > 0) toast(`Back online — synced ${synced} change${synced > 1 ? 's' : ''} to server`, 'success')
    if (failed > 0) toast(`${failed} change${failed > 1 ? 's' : ''} couldn't sync — may need your review`, 'warn')
  }

  function setOnline(value: boolean) {
    const wasOffline = !state.online
    state.online = value
    if (value && wasOffline) flushQueue()
    else if (!value) toast('You are offline — changes will be saved locally and synced when reconnected', 'warn')
  }

  return {
    online: computed(() => state.online),
    pendingCount: computed(() => state.queue.length),
    queueOrRun,
    setOnline,
    hydrate,
  }
}
