<template>
  <div>
    <div class="page-header">
      <div><h1>Configure Lab Result Templates</h1><div class="desc">Manage reusable structures for laboratory data entry.</div></div>
      <div class="page-actions"><button class="btn btn-primary" @click="newTemplate"><Icon name="plus" :size="14" /> Create New Template</button></div>
    </div>
    <div v-if="active" class="grid" style="grid-template-columns:230px 1fr; gap:18px; align-items:start;">
      <div class="card">
        <div class="card-header"><h3><Icon name="clipboard" :size="15" /> Saved Templates</h3></div>
        <div class="card-body tight">
          <div v-for="t in templates" :key="t.id" class="list-row clickable" :style="{ background: t.id === active.id ? 'var(--blue-50)' : 'transparent' }" @click="select(t)">
            <Icon name="flask" :size="14" /><span class="main-txt" style="margin-left:8px;">{{ t.name }}</span>
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
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const templates = ref<any[]>([])
const active = ref<any>(null)
const draft = reactive({ name: '', category: '', description: '', variables: [] as any[] })
const saving = ref(false)

await useAsyncData(`lab-templates-manager-${props.role}`, async () => {
  const { data } = await supabase.from('lab_templates').select('*').order('name', { ascending: true })
  templates.value = data || []
  if (templates.value[0]) select(templates.value[0])
  return true
})

function select(t: any) {
  active.value = t
  draft.name = t.name
  draft.category = t.category || ''
  draft.description = t.description || ''
  draft.variables = (t.variables || []).map((v: any) => ({ ...v }))
}

async function newTemplate() {
  const { data, error } = await supabase.from('lab_templates').insert({ name: 'New Template', category: 'General', description: '', variables: [] }).select().single()
  if (error) return
  templates.value = [...templates.value, data]
  select(data)
}

async function save() {
  if (!active.value) return
  saving.value = true
  await queueOrRun(`Template "${draft.name}" saved`, async () => {
    const { error } = await supabase
      .from('lab_templates')
      .update({ name: draft.name, category: draft.category, description: draft.description, variables: draft.variables })
      .eq('id', active.value.id)
    if (error) throw error
    const idx = templates.value.findIndex((t) => t.id === active.value.id)
    if (idx !== -1) templates.value[idx] = { ...active.value, ...draft }
    active.value = templates.value[idx]
  })
  saving.value = false
}
</script>
