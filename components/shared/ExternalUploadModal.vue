<template>
  <Modal :model-value="modelValue" title="Attach External Lab Result" @update:model-value="$emit('update:modelValue', $event)">
    <div class="field">
      <label>Patient</label>
      <select v-model="patientId" class="input">
        <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option>
      </select>
    </div>
    <div class="form-row">
      <div class="field"><label>Document Title</label><input v-model="title" class="input" placeholder="e.g. Lagos Labs - Blood Panel" /></div>
      <div class="field"><label>Date of Test</label><input v-model="date" class="input" type="date" /></div>
    </div>
    <div class="field">
      <label>Upload Document</label>
      <input ref="fileInput" type="file" accept="application/pdf,image/*" style="display:none" @change="onFile" />
      <div
        style="border:1.5px dashed var(--border-strong); border-radius:var(--radius-sm); padding:26px; text-align:center; color:var(--text-500); font-size:12.5px; cursor:pointer;"
        @click="fileInput?.click()"
      >
        <Icon name="upload" :size="20" />
        <div style="margin-top:8px;">{{ chosenFile ? chosenFile.name : 'Click to browse for a PDF or image scan' }}</div>
      </div>
      <div class="hint"><Icon name="lock" :size="10" /> Max file size 10MB. Secured via Supabase Storage.</div>
    </div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="!patientId || submitting" @click="submit"><Icon name="upload" :size="13" /> Upload &amp; Secure Document</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ modelValue: boolean; preselectedPatientId?: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; uploaded: [] }>()

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const patients = ref<any[]>([])
const patientId = ref('')
const title = ref('')
const date = ref(new Date().toISOString().slice(0, 10))
const chosenFile = ref<File | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)
const submitting = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    title.value = ''
    chosenFile.value = null
    patientId.value = props.preselectedPatientId || ''
    if (!patients.value.length) {
      const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
      patients.value = data || []
      if (!patientId.value) patientId.value = patients.value[0]?.patient_id || ''
    }
  }
)

function onFile(e: Event) {
  chosenFile.value = (e.target as HTMLInputElement).files?.[0] || null
}

async function submit() {
  if (!patientId.value) return
  submitting.value = true

  await queueOrRun(`"${title.value || 'External Result'}" attached to patient file`, async () => {
    let externalFileUrl: string | null = null
    if (chosenFile.value) {
      const path = `${patientId.value}/${Date.now()}-${chosenFile.value.name}`
      const { error: upErr } = await supabase.storage.from('lab-external-results').upload(path, chosenFile.value)
      if (upErr) throw upErr
      externalFileUrl = path
    }

    const { error } = await supabase.from('lab_results').insert({
      patient_id: patientId.value,
      entered_by_profile_id: profile.value!.id,
      collected_on: date.value,
      title: title.value || 'External Result',
      external: true,
      external_file_url: externalFileUrl,
    })
    if (error) throw error
  })

  submitting.value = false
  emit('uploaded')
  emit('update:modelValue', false)
}
</script>
