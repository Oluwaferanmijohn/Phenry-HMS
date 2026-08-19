import { reactive, computed } from 'vue'
import { useToast } from '~/composables/useToast'

interface QueuedWrite {
  id: number
  label: string
  run: () => Promise<void> | void
}

// Module-level shared state, same reasoning as useToast: one sync pill,
// one queue, for the whole app.
const state = reactive<{ online: boolean; queue: QueuedWrite[] }>({
  online: true, // plugins/sync.client.ts corrects this to navigator.onLine on mount
  queue: [],
})
let nextId = 1

export function useSyncQueue() {
  const { toast } = useToast()

  // TODO(PowerSync): once the PowerSync client is wired (after all 10 roles'
  // tables exist and a bucket schema can be finalized), `run` below should
  // become a write to the local PowerSync/SQLite database instead of a
  // direct Supabase call — PowerSync's own upload queue then takes over
  // "pending" tracking and this in-memory queue goes away. Until then this
  // queue is the real (if simpler) mechanism, not a simulation: writes made
  // while genuinely offline are held here and flushed on reconnect.
  async function queueOrRun(label: string, run: () => Promise<void> | void) {
    if (state.online) {
      try {
        await run()
        toast(label, 'success')
      } catch (err) {
        toast('Something went wrong — please try again', 'warn')
        throw err
      }
    } else {
      state.queue.push({ id: nextId++, label, run })
      toast(`Saved locally — will sync when back online (${state.queue.length} pending)`, 'warn')
    }
  }

  async function flushQueue() {
    if (!state.queue.length) return
    const pending = [...state.queue]
    state.queue.length = 0
    for (const item of pending) {
      try {
        await item.run()
      } catch {
        // Re-queue anything that fails to send even though we're back online
        state.queue.push(item)
      }
    }
    const synced = pending.length - state.queue.length
    if (synced > 0) toast(`Back online — synced ${synced} change${synced > 1 ? 's' : ''} to server`, 'success')
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
  }
}
