<template>
  <Modal :model-value="modelValue" :title="surgery ? 'Procedure Report — ' + surgery.procedure : ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="surgery && report">
      <p class="cell-muted" style="margin-bottom:14px;">Patient: {{ patientName }} &nbsp;·&nbsp; Procedure: {{ surgery.procedure }} &nbsp;·&nbsp; <StatusBadge :status="surgery.status" /></p>
      <div class="tabs" style="margin-bottom:14px;">
        <div class="tab" :class="{ active: tab === 'preop' }" @click="tab = 'preop'">Pre-Op Assessment</div>
        <div class="tab" :class="{ active: tab === 'opnotes' }" @click="tab = 'opnotes'">Operative Notes</div>
        <div class="tab" :class="{ active: tab === 'postop' }" @click="tab = 'postop'">Post-Op Orders</div>
      </div>

      <template v-if="tab === 'preop'">
        <div style="display:flex; flex-direction:column; gap:10px;">
          <label class="checkbox-row"><input v-model="preOp.consentVerified" type="checkbox" /><span>Patient ID &amp; Consent Form Verified</span></label>
          <label class="checkbox-row"><input v-model="preOp.fastingConfirmed" type="checkbox" /><span>Fasting (NPO) Confirmed</span></label>
          <label class="checkbox-row"><input v-model="preOp.gownChanged" type="checkbox" /><span>Patient Changed Into Hospital Gown</span></label>
          <label class="checkbox-row"><input v-model="preOp.allergiesReviewed" type="checkbox" /><span>Allergies &amp; Chart Reviewed</span></label>
        </div>
        <div class="field" style="margin-top:12px;"><label>Pre-Op Notes</label><textarea v-model="preOp.notes" class="input" rows="3" /></div>
        <div style="margin-top:14px; text-align:right;"><button class="btn btn-primary" @click="save('preop')"><Icon name="check-circle" :size="13" /> Save Pre-Op Assessment</button></div>
      </template>

      <template v-else-if="tab === 'opnotes'">
        <div class="form-row">
          <div class="field">
            <label>Primary Surgeon</label>
            <select v-model="opNotes.surgeon" class="input"><option value="">Select…</option><option v-for="p in providers" :key="p.id" :value="p.full_name">{{ p.full_name }}</option></select>
          </div>
          <div class="field"><label>Attending Anesthetist</label><input v-model="opNotes.anesthetist" class="input" /></div>
        </div>
        <div class="field"><label>Detailed Surgical Narrative</label><textarea v-model="opNotes.narrative" class="input" rows="4" placeholder="Enter operative findings, procedure steps, and detailed narrative here…" /></div>
        <div class="form-row">
          <div class="field"><label>Total Oocytes (Eggs) Retrieved</label><input v-model="opNotes.eggsRetrieved" class="input" type="number" /></div>
          <div class="field"><label>Were there any complications?</label><select v-model="opNotes.complications" class="input"><option>No</option><option>Yes</option></select></div>
        </div>
        <div style="margin-top:14px; text-align:right;"><button class="btn btn-primary" @click="save('opnotes')"><Icon name="check-circle" :size="13" /> Sign &amp; Save Operative Notes</button></div>
      </template>

      <template v-else>
        <div class="field"><label>Recovery Instructions</label><textarea v-model="postOp.recoveryInstructions" class="input" rows="3" placeholder="Instructions for recovery ward staff…" /></div>
        <div class="field"><label>Pain Management Orders</label><textarea v-model="postOp.painManagement" class="input" rows="2" placeholder="e.g. Paracetamol 1g PO q6h PRN" /></div>
        <label class="checkbox-row"><input v-model="postOp.dischargeCriteriaMet" type="checkbox" /><span>Discharge Criteria Met</span></label>
        <div style="margin-top:14px; text-align:right;"><button class="btn btn-success" @click="save('postop')"><Icon name="check-circle" :size="13" /> Save Post-Op Orders</button></div>
      </template>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; surgeryId: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const tab = ref<'preop' | 'opnotes' | 'postop'>('preop')
const surgery = ref<any>(null)
const report = ref<any>(null)
const patientName = ref('')
const providers = ref<any[]>([])

const preOp = reactive({ consentVerified: false, fastingConfirmed: false, gownChanged: false, allergiesReviewed: false, notes: '' })
const opNotes = reactive({ surgeon: '', anesthetist: '', narrative: '', eggsRetrieved: '', complications: 'No' })
const postOp = reactive({ recoveryInstructions: '', painManagement: '', dischargeCriteriaMet: false })

watch(
  () => [props.modelValue, props.surgeryId],
  async ([open]) => {
    if (!open || !props.surgeryId) return
    tab.value = 'preop'
    const [surgeryRes, reportRes, providersRes] = await Promise.all([
      supabase.from('surgery_schedule').select('*, patient_names(full_name)').eq('id', props.surgeryId).single(),
      supabase.from('operative_reports').select('*').eq('surgery_id', props.surgeryId).single(),
      supabase.from('profiles').select('id, full_name').in('role', ['doctor', 'matron']),
    ])
    surgery.value = surgeryRes.data
    patientName.value = surgeryRes.data?.patient_names?.full_name || 'Unknown'
    report.value = reportRes.data
    providers.value = providersRes.data || []
    Object.assign(preOp, report.value?.pre_op || {})
    Object.assign(opNotes, report.value?.op_notes || {})
    Object.assign(postOp, report.value?.post_op || {})
  },
  { immediate: true }
)

async function save(which: 'preop' | 'opnotes' | 'postop') {
  const label = which === 'preop' ? 'Pre-Op assessment' : which === 'opnotes' ? 'Operative notes' : 'Post-op orders'
  const targetSurgeryId = props.surgeryId
  const patch: any = {}
  if (which === 'preop') patch.pre_op = { ...preOp }
  if (which === 'opnotes') patch.op_notes = { ...opNotes }
  if (which === 'postop') patch.post_op = { ...postOp }

  await queueOrRun(`${label} saved`, async () => {
    const { error } = await supabase.from('operative_reports').update(patch).eq('surgery_id', targetSurgeryId)
    if (error) throw error

    if (which === 'opnotes') {
      await supabase.from('surgery_schedule').update({ status: 'Completed' }).eq('id', targetSurgeryId)
    }
  })
  emit('saved')
}
</script>
