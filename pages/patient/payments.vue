<template>
  <div>
    <EmptyState
      v-if="!plan"
      icon="cash"
      title="No payment plan yet"
      description="Your billing team will generate a payment plan once your treatment package is confirmed."
    />
    <template v-else>
      <div class="page-header">
        <div>
          <h1>{{ plan.package }} Payment Plan</h1>
          <div class="desc">Total package cost: {{ fmtNaira(plan.total_cost) }}</div>
        </div>
      </div>

      <div class="grid grid-main-side">
        <div class="card">
          <div class="card-header"><h3><Icon name="cash" :size="15" /> Milestones</h3></div>
          <div class="card-body tight">
            <div v-for="m in milestones" :key="m.id" class="list-row" style="align-items:flex-start;">
              <div
                class="icon-wrap"
                :style="{
                  background: m.status === 'Paid' ? 'var(--green-50)' : 'var(--blue-50)',
                  color: m.status === 'Paid' ? 'var(--green-600)' : 'var(--blue-600)',
                  width: '34px', height: '34px', borderRadius: '9px', display: 'flex', alignItems: 'center', justifyContent: 'center',
                }"
              >
                <Icon :name="m.status === 'Paid' ? 'check-circle' : 'cash'" :size="15" />
              </div>
              <div>
                <div class="flex gap-8"><span class="main-txt">{{ m.label }}</span><StatusBadge :status="m.status" /></div>
                <div class="sub-txt">{{ m.due_context }} · {{ fmtNaira(m.amount) }}</div>
                <button v-if="m.status !== 'Paid' && !m.proof_url" class="btn btn-primary btn-sm" style="margin-top:8px;" @click="openUploadProof(m)">
                  <Icon name="upload" :size="12" /> Upload Proof of Payment
                </button>
                <div v-if="m.proof_url && m.status !== 'Paid'" class="sub-txt" style="color:var(--amber-600); margin-top:6px;">
                  <Icon name="clock" :size="11" /> Proof submitted — awaiting Admin verification
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="card card-pad">
          <h3 style="font-size:13.5px;"><Icon name="building" :size="14" /> Clinic Payment Details</h3>
          <div style="margin-top:12px; display:flex; flex-direction:column; gap:10px; font-size:12.5px;">
            <div><div class="muted" style="font-size:11px;">BANK NAME</div><div style="font-weight:600;">{{ bank.name }}</div></div>
            <div><div class="muted" style="font-size:11px;">ACCOUNT NUMBER</div><div style="font-weight:600;">{{ bank.accountNumber }}</div></div>
            <div><div class="muted" style="font-size:11px;">ACCOUNT NAME</div><div style="font-weight:600;">{{ bank.accountName }}</div></div>
          </div>
          <hr class="hr" />
          <p class="muted" style="font-size:11.5px;"><Icon name="check-circle" :size="11" /> Please ensure you include your Patient ID ({{ patientId }}) in the transfer reference.</p>
        </div>
      </div>
    </template>

    <Modal v-model="showUploadModal" title="Upload Proof of Payment">
      <div class="field"><label>Amount Paid</label><input v-model="uploadAmount" class="input" placeholder="₦0.00" /></div>
      <div class="field"><label>Payment Date</label><input v-model="uploadDate" class="input" type="date" /></div>
      <div class="field">
        <label>Upload Receipt</label>
        <input ref="fileInput" type="file" accept="image/*,application/pdf" style="display:none" @change="onFileChosen" />
        <div
          style="border:1.5px dashed var(--border-strong); border-radius:var(--radius-sm); padding:26px; text-align:center; color:var(--text-500); font-size:12.5px; cursor:pointer;"
          @click="fileInput?.click()"
        >
          <Icon name="upload" :size="20" />
          <div style="margin-top:8px;">{{ chosenFile ? chosenFile.name : 'Click to browse for a PDF or image' }}</div>
        </div>
      </div>
      <template #footer>
        <button class="btn btn-secondary" @click="showUploadModal = false">Cancel</button>
        <button class="btn btn-primary" :disabled="!chosenFile || submitting" @click="submitProof">
          <Icon name="upload" :size="13" /> {{ submitting ? 'Submitting…' : 'Submit for Verification' }}
        </button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtNaira } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const patientId = profile.value!.patient_id!

const plan = ref<any>(null)
const milestones = ref<any[]>([])
const bank = ref<any>({ name: '', accountName: '', accountNumber: '' })

const { data } = await useAsyncData(`patient-payments-${patientId}`, async () => {
  const [planRes, settingsRes] = await Promise.all([
    supabase.from('payment_plans').select('*, payment_milestones(*)').eq('patient_id', patientId).limit(1).maybeSingle(),
    supabase.from('clinic_settings').select('bank').eq('id', 1).single(),
  ])
  return { plan: planRes.data, bank: settingsRes.data?.bank || {} }
})

if (data.value) {
  plan.value = data.value.plan
  milestones.value = data.value.plan?.payment_milestones || []
  bank.value = data.value.bank
}

const showUploadModal = ref(false)
const activeMilestone = ref<any>(null)
const uploadAmount = ref('')
const uploadDate = ref('')
const chosenFile = ref<File | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)
const submitting = ref(false)

function openUploadProof(m: any) {
  activeMilestone.value = m
  uploadAmount.value = ''
  uploadDate.value = ''
  chosenFile.value = null
  showUploadModal.value = true
}

function onFileChosen(e: Event) {
  chosenFile.value = (e.target as HTMLInputElement).files?.[0] || null
}

async function submitProof() {
  if (!chosenFile.value || !activeMilestone.value) return
  submitting.value = true

  const path = `${patientId}/${activeMilestone.value.id}/${Date.now()}-${chosenFile.value.name}`
  const { error: uploadError } = await supabase.storage.from('payment-proofs').upload(path, chosenFile.value)
  if (uploadError) {
    submitting.value = false
    toast('Could not upload the file — please try again', 'warn')
    return
  }

  const { data: updated, error: updateError } = await supabase
    .from('payment_milestones')
    .update({ proof_url: path, status: 'Pending Verification' })
    .eq('id', activeMilestone.value.id)
    .select()
    .single()

  submitting.value = false
  if (updateError) {
    toast('File uploaded, but could not update the milestone — contact support', 'warn')
    return
  }

  const idx = milestones.value.findIndex((m) => m.id === activeMilestone.value.id)
  if (idx !== -1) milestones.value[idx] = updated

  toast('Proof of payment submitted for verification', 'success')
  showUploadModal.value = false
}
</script>
