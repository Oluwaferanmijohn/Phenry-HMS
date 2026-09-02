<template>
  <div>
    <div class="page-header">
      <div><h1>Configure Lab Result Templates</h1><div class="desc">Use the included fertility-lab templates or create a structure for another test.</div></div>
      <div class="page-actions">
        <button class="btn btn-secondary" :disabled="installingStarters" @click="installStarterTemplates(false)"><Icon name="refresh" :size="14" /> Restore Starter Templates</button>
        <button class="btn btn-primary" @click="newTemplate"><Icon name="plus" :size="14" /> Create New Template</button>
      </div>
    </div>
    <div v-if="loadError" class="template-alert"><Icon name="alert" :size="15" /><span>{{ loadError }}</span><button class="btn btn-secondary btn-sm" @click="loadTemplates()">Retry</button></div>
    <div v-if="installMessage" class="template-success"><Icon name="check-circle" :size="15" /><span>{{ installMessage }}</span></div>
    <div v-if="active" class="grid" style="grid-template-columns:230px 1fr; gap:18px; align-items:start;">
      <div class="card">
        <div class="card-header"><h3><Icon name="clipboard" :size="15" /> Saved Templates</h3></div>
        <div class="card-body tight">
          <div v-for="t in templates" :key="t.id" class="list-row clickable" :style="{ background: t.id === active.id ? 'var(--blue-50)' : 'transparent' }" @click="select(t)">
            <Icon name="flask" :size="14" /><span class="main-txt" style="margin-left:8px;">{{ t.name }}</span><Badge v-if="isStarter(t)" tone="blue">Starter</Badge>
          </div>
        </div>
      </div>
      <div class="card card-pad">
        <b style="font-size:12.5px;"><Icon name="settings" :size="12" /> Template Settings</b>
        <div class="form-row" style="margin-top:10px;">
          <div class="field"><label>Template Name</label><input v-model="draft.name" class="input" /></div>
          <div class="field"><label>Category</label><input v-model="draft.category" class="input" /></div>
        </div>
        <div class="field"><label>Description (Optional)</label><textarea v-model="draft.description" class="input" rows="2" /></div>
        <div class="template-note"><Icon name="shield" :size="15" /><span>Starter templates provide reporting fields only. Enter the reference intervals validated for your laboratory's assay and specimen method.</span></div>
        <hr class="hr" />
        <div class="flex-between"><b style="font-size:12.5px;"><Icon name="edit" :size="12" /> Variable Fields</b><Badge tone="blue">{{ draft.variables.length }} Variables</Badge></div>
        <div style="margin-top:10px; display:flex; flex-direction:column; gap:8px;">
          <div v-for="(v, i) in draft.variables" :key="i" class="form-row" style="grid-template-columns: 1.4fr 1fr 1fr auto;">
            <input v-model="v.name" class="input" placeholder="Variable Name" />
            <input v-model="v.unit" class="input" placeholder="Unit" />
            <input v-model="v.ref" class="input" placeholder="Reference Range" />
            <button class="icon-btn" style="color:var(--red-600);" @click="draft.variables.splice(i, 1)"><Icon name="trash" :size="13" /></button>
          </div>
        </div>
        <button class="btn btn-secondary btn-sm" style="margin-top:10px; border-style:dashed;" @click="draft.variables.push({ name: '', unit: '', ref: '' })"><Icon name="plus" :size="12" /> Add New Variable</button>
        <div class="flex-between" style="margin-top:18px;">
          <span />
          <div class="flex gap-10"><button class="btn btn-secondary" @click="select(active)">Cancel</button><button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save Template Structure</button></div>
        </div>
      </div>
    </div>
    <div v-else-if="!loading" class="card card-pad empty-template-state">
      <Icon name="clipboard" :size="28" />
      <h3>No result templates are installed</h3>
      <p>Restore the fertility-lab starter library to add SFA, IVF monitoring, hormonal, pregnancy, blood, and screening templates.</p>
      <button class="btn btn-primary" :disabled="installingStarters" @click="installStarterTemplates(false)"><Icon name="plus" :size="13" /> Install Starter Templates</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'
import { STARTER_LAB_TEMPLATE_IDS, STARTER_LAB_TEMPLATES } from '~/utils/labStarterTemplates'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()

const templates = ref<any[]>([])
const active = ref<any>(null)
const draft = reactive({ name: '', category: '', description: '', variables: [] as any[] })
const saving = ref(false)
const loading = ref(true)
const installingStarters = ref(false)
const loadError = ref('')
const installMessage = ref('')

await useAsyncData(`lab-templates-manager-${props.role}`, async () => {
  await loadTemplates(true)
  return true
})

async function fetchTemplates() {
  const { data, error } = await supabase.from('lab_templates').select('*').order('name', { ascending: true })
  if (error) throw error
  templates.value = data || []
  if (active.value) {
    const refreshed = templates.value.find((template) => template.id === active.value.id)
    if (refreshed) select(refreshed)
    else active.value = null
  }
  if (!active.value && templates.value[0]) select(templates.value[0])
}

async function loadTemplates(autoRestore = false) {
  loading.value = true
  loadError.value = ''
  try {
    await fetchTemplates()
    if (autoRestore) await installStarterTemplates(true)
  } catch (error: any) {
    loadError.value = error?.message || 'Templates could not be loaded. Check your connection and laboratory access.'
  } finally {
    loading.value = false
  }
}

async function installStarterTemplates(silent: boolean) {
  if (installingStarters.value) return
  installingStarters.value = true
  installMessage.value = ''
  loadError.value = ''
  try {
    const existingNames = new Set(templates.value.map((template) => String(template.name || '').trim().toLowerCase()))
    const missing = STARTER_LAB_TEMPLATES.filter((template) => !existingNames.has(template.name.toLowerCase()))
    if (missing.length) {
      const { error } = await supabase.from('lab_templates').upsert(missing, { onConflict: 'id', ignoreDuplicates: true })
      if (error) throw error
      await fetchTemplates()
    }
    if (!silent) {
      installMessage.value = missing.length ? `${missing.length} starter template${missing.length === 1 ? '' : 's'} installed.` : 'All starter templates are already installed.'
      toast(installMessage.value, 'success')
    }
  } catch (error: any) {
    loadError.value = error?.message || 'Starter templates could not be installed.'
    if (!silent) toast(loadError.value, 'warn')
  } finally {
    installingStarters.value = false
  }
}

function isStarter(template: any) {
  return STARTER_LAB_TEMPLATE_IDS.has(template.id)
}

function select(t: any) {
  active.value = t
  draft.name = t.name
  draft.category = t.category || ''
  draft.description = t.description || ''
  draft.variables = (t.variables || []).map((v: any) => ({ ...v }))
}

async function newTemplate() {
  const { data, error } = await supabase.from('lab_templates').insert({ name: 'New Template', category: 'General', description: '', variables: [] }).select().single()
  if (error) return toast(error.message, 'warn')
  templates.value = [...templates.value, data]
  select(data)
}

async function save() {
  if (!active.value) return
  saving.value = true
  const targetId = active.value.id
  const snapshot = { name: draft.name, category: draft.category, description: draft.description, variables: draft.variables.map((v: any) => ({ ...v })) }
  await queueOrRun(
    `Template "${snapshot.name}" saved`,
    { table: 'lab_templates', kind: 'update', payload: snapshot, match: { id: targetId } },
    () => {
      const idx = templates.value.findIndex((t) => t.id === targetId)
      if (idx !== -1) {
        templates.value[idx] = { ...templates.value[idx], ...snapshot }
        if (active.value?.id === targetId) active.value = templates.value[idx]
      }
    }
  )
  saving.value = false
}
</script>

<style scoped>
.template-note { display: flex; align-items: flex-start; gap: 8px; margin-top: 12px; padding: 10px 12px; border: 1px solid var(--blue-100); border-radius: var(--radius-sm); background: var(--blue-50); color: var(--text-700); font-size: 11.5px; line-height: 1.45; }
.template-note svg { flex-shrink: 0; color: var(--blue-600); }
.template-alert, .template-success { display: flex; align-items: center; gap: 9px; margin-bottom: 14px; padding: 11px 13px; border-radius: var(--radius-sm); font-size: 11.5px; }
.template-alert { border: 1px solid var(--red-200); background: var(--red-50); color: var(--red-700); }
.template-success { border: 1px solid var(--green-200); background: var(--green-50); color: var(--green-700); }
.template-alert span, .template-success span { flex: 1; }
.empty-template-state { display: grid; justify-items: center; gap: 9px; min-height: 260px; align-content: center; color: var(--text-500); text-align: center; }
.empty-template-state h3 { margin: 0; color: var(--text-900); }
.empty-template-state p { max-width: 520px; margin: 0 0 5px; font-size: 12px; line-height: 1.55; }
</style>
