<template>
  <div>
    <div class="page-header"><div><h1>Active Worklist</h1><div class="desc">{{ items.length }} tasks queued.</div></div></div>
    <div class="grid" style="grid-template-columns:320px 1fr; gap:18px; align-items:start;">
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card">
          <div class="card-header"><h3><Icon name="grid" :size="15" /> Active Worklist</h3><Badge tone="amber">{{ items.length }} Pending</Badge></div>
          <div class="card-body tight">
            <div v-if="!items.length" style="padding:18px;"><EmptyState icon="grid" title="Nothing queued" description="Scheduled transfers and freezes needing action will appear here." /></div>
            <div v-for="it in items" :key="it.id" class="list-row clickable" @click="$router.push(`/${role}/embryo?patient=${it.patient_id}`)">
              <div><div class="main-txt">{{ it.patient_name }} — {{ it.type }}</div><div class="sub-txt">{{ fmtDate(it.scheduled_date) }}</div></div>
              <div class="side"><StatusBadge :status="it.status" /></div>
            </div>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="flask" :size="15" /> Pending Test Orders</h3><Badge tone="amber">{{ orders.length }}</Badge></div>
          <div class="card-body tight">
            <div v-if="!orders.length" style="padding:18px;"><EmptyState icon="flask" title="Nothing ordered" description="Tests ordered by Doctor or Matron during a consultation will appear here." /></div>
            <div
              v-for="o in orders"
              :key="o.id"
              class="list-row clickable"
              style="align-items:stretch; flex-direction:column; gap:10px;"
              role="link"
              tabindex="0"
              @click="openOrder(o)"
              @keydown.enter.self="openOrder(o)"
              @keydown.space.self.prevent="openOrder(o)"
            >
              <div class="flex-between" style="align-items:flex-start; gap:10px;">
                <div>
                  <div class="main-txt">{{ o.patient_name }}</div>
                  <div class="sub-txt">{{ o.tests.join(', ') }}</div>
                  <div class="cell-muted">Ordered {{ fmtDate(o.created_at) }} by {{ roleLabel(o.ordered_by_role) }}</div>
                </div>
                <StatusBadge :status="o.status" />
              </div>
              <div class="flex gap-8" style="flex-wrap:wrap;" @click.stop>
                <button class="btn btn-primary btn-sm" @click="openOrder(o)"><Icon name="flask" :size="12" /> Enter Results</button>
                <button v-if="o.status === 'Ordered'" class="btn btn-secondary btn-sm" @click="actionOrder(o, 'Collected')">Mark Collected</button>
                <button class="btn btn-secondary btn-sm" @click="actionOrder(o, 'Cancelled')">Cancel</button>
              </div>
            </div>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="clipboard" :size="15" /> Reusable Result Templates</h3><span class="link" @click="$router.push(`/${role}/templates`)">Manage</span></div>
          <div class="card-body tight">
            <div v-for="t in templates" :key="t.id" class="list-row clickable" @click="$router.push(`/${role}/templates`)">
              <div class="icon-wrap" style="width:30px;height:30px;border-radius:8px;background:var(--blue-50);color:var(--blue-600);display:flex;align-items:center;justify-content:center;"><Icon name="flask" :size="14" /></div>
              <div class="main-txt">{{ t.name }}</div>
            </div>
          </div>
        </div>
      </div>
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="layers" :size="13" /> Today's Priorities</b>
          <p class="cell-muted" style="margin-top:6px; font-size:12.5px;">Jump straight into a task: enter lab results, grade embryos in bulk, or action the transfer/cryo schedule.</p>
          <div style="display:flex; flex-direction:column; gap:8px; margin-top:12px;">
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push(`/${role}/results`)"><Icon name="flask" :size="14" /> Enter Lab Results</button>
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push(`/${role}/embryo`)"><Icon name="layers" :size="14" /> Embryo Development Grading</button>
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push(`/${role}/schedule`)"><Icon name="calendar" :size="14" /> Fertility Procedures &amp; Cryostorage</button>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="calendar" :size="15" /> Transfers &amp; Freezes — Today</h3><span class="link" @click="$router.push(`/${role}/schedule`)">View schedule</span></div>
          <div class="card-body tight">
            <div v-if="!today.length" style="padding:18px;"><EmptyState icon="calendar" title="Nothing today" description="No transfers or freezes scheduled today." /></div>
            <div v-for="it in today" :key="it.id" class="list-row">
              <div><div class="main-txt">{{ it.patient_name }}</div><div class="sub-txt">{{ it.type }}</div></div>
              <div class="side"><StatusBadge :status="it.status" /></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { isFertilityLabProcedure } from '~/composables/useFertilityProcedures'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const router = useRouter()

const items = ref<any[]>([])
const templates = ref<any[]>([])
const orders = ref<any[]>([])

await useAsyncData(`lab-worklist-${props.role}`, async () => {
  // Postponed items still need to come back for action — an "active"
  // worklist that drops them the moment they're postponed is exactly how
  // they get forgotten. Scheduled + Postponed both count as active; only
  // Done/Cancelled are excluded.
  const [scheduleRes, clinicalScheduleRes, templatesRes, ordersRes] = await Promise.all([
    supabase.from('transfer_cryo_schedule').select('*, patient_names(full_name)').in('status', ['Scheduled', 'Postponed']).order('scheduled_date', { ascending: true }),
    supabase.from('surgery_schedule').select('*, patient_names(full_name)').in('status', ['Scheduled', 'Postponed']).order('date', { ascending: true }),
    supabase.from('lab_templates').select('*').order('name', { ascending: true }),
    supabase.from('lab_test_orders').select('*, patient_names(full_name)').in('status', ['Ordered', 'Collected']).order('created_at', { ascending: false }),
  ])
  const legacyItems = (scheduleRes.data || []).map((it: any) => ({ ...it, patient_name: it.patient_names?.full_name || 'Unknown' }))
  const clinicalItems = (clinicalScheduleRes.data || [])
    .filter((it: any) => isFertilityLabProcedure(it.procedure))
    .map((it: any) => ({ ...it, type: it.procedure, scheduled_date: it.date, patient_name: it.patient_names?.full_name || 'Unknown' }))
  items.value = [...clinicalItems, ...legacyItems].sort((a: any, b: any) => a.scheduled_date.localeCompare(b.scheduled_date))
  templates.value = templatesRes.data || []
  orders.value = (ordersRes.data || []).map((o: any) => ({ ...o, patient_name: o.patient_names?.full_name || 'Unknown' }))
  return true
})

const todayStr = new Date().toISOString().slice(0, 10)
const today = computed(() => items.value.filter((it) => it.scheduled_date === todayStr))

function roleLabel(role: string) {
  return role.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function openOrder(order: any) {
  router.push({
    path: `/${props.role}/results`,
    query: { patient: order.patient_id, order: order.id },
  })
}

async function actionOrder(order: any, status: 'Collected' | 'Cancelled') {
  const { error } = await supabase.from('lab_test_orders').update({ status }).eq('id', order.id)
  if (error) return
  if (status === 'Cancelled') {
    orders.value = orders.value.filter((o) => o.id !== order.id)
    return
  }
  order.status = status
}
</script>
