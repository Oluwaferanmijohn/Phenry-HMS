import { watch } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'

// Every page in this app loads its data once via `await useAsyncData(key,
// load)` and never refetches — so a consultation note, a lab result, a
// dispensed prescription, a new cycle, anything written by one user/role
// doesn't show up for anyone already sitting on a related screen until they
// manually reload. That's true across every dashboard, not just one page,
// so this is fixed once, globally, instead of hand-wiring 70+ pages:
//
// One Supabase Realtime channel listens for Postgres changes on every
// clinically/operationally relevant table (see
// 00000000000015_realtime_sync.sql for the publication + replica identity
// setup this depends on), and on any change calls Nuxt's refreshNuxtData()
// with NO key argument. That re-runs every useAsyncData handler currently
// active on whatever page the user is actually looking at — the exact same
// load() function and key each page already defines — so there is nothing
// to add to individual pages/components, and it keeps working automatically
// as new pages get built.
//
// Trade-off worth knowing: because it's a blanket "whatever's currently on
// screen, refresh it" rather than a per-table -> per-page dependency map,
// an unrelated table change can occasionally trigger a redundant refetch of
// the current page's own (unrelated) data. That's a harmless extra read,
// not a correctness issue, and it's a good trade for not having to
// hand-maintain a table/page map across 10 roles.
//
// Security note: Realtime's Postgres Changes feed evaluates each
// subscriber's own RLS SELECT policies per row before delivering an event —
// the same policies already enforced on every table here — so this can't
// leak a patient's or another role's data to someone who couldn't already
// query it directly.
const REALTIME_TABLES = [
  'profiles', 'patient_names', 'bio_details',
  'cycles', 'cycle_daily_logs', 'cycle_investigations', 'cycle_ultrasounds',
  'consultations', 'appointments',
  'payment_plans', 'payment_milestones',
  'prescriptions', 'pharmacy_inventory', 'requisitions',
  'lab_results', 'lab_templates',
  'recovery_beds', 'surgery_schedule', 'operative_reports', 'duty_roster',
  'embryo_batches', 'transfer_cryo_schedule', 'cryo_tanks', 'cryo_records',
  'incubator_logs', 'lab_equipment', 'lab_store',
  'messages_log', 'audit_log', 'clinic_settings',
  'custom_roles', 'role_permissions',
]

const DEBOUNCE_MS = 300

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  let channel: RealtimeChannel | null = null
  let debounceTimer: ReturnType<typeof setTimeout> | null = null

  function scheduleRefresh() {
    // Collapse bursts of related changes (e.g. approving a requisition
    // updates both requisitions and pharmacy_inventory in quick succession)
    // into a single refresh instead of firing one per row event.
    if (debounceTimer) clearTimeout(debounceTimer)
    debounceTimer = setTimeout(() => {
      refreshNuxtData()
    }, DEBOUNCE_MS)
  }

  function subscribe() {
    if (channel) return
    let ch = supabase.channel('app-wide-realtime-sync')
    for (const table of REALTIME_TABLES) {
      ch = ch.on('postgres_changes', { event: '*', schema: 'public', table }, scheduleRefresh)
    }
    ch.subscribe()
    channel = ch
  }

  function unsubscribe() {
    if (debounceTimer) {
      clearTimeout(debounceTimer)
      debounceTimer = null
    }
    if (channel) {
      supabase.removeChannel(channel)
      channel = null
    }
  }

  // Subscribe once a session exists, tear down on logout — also handles a
  // different user signing in without a full page reload.
  watch(user, (u) => (u ? subscribe() : unsubscribe()), { immediate: true })
})
