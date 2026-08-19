<template>
  <div>
    <div class="page-header"><div><h1>Global System Configuration</h1><div class="desc">Manage company profile, clinic-wide financial details, and operational scheduling.</div></div></div>
    <div v-if="cs" class="grid grid-2">
      <div class="card">
        <div class="card-header"><h3><Icon name="building" :size="15" /> Company Profile</h3></div>
        <div class="card-body">
          <div class="flex gap-14" style="align-items:center; margin-bottom:16px;">
            <div style="width:60px;height:60px;border-radius:14px;background:var(--blue-50);color:var(--blue-600);display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:800; flex-shrink:0;">{{ (cs.clinic_name || 'P')[0] }}</div>
            <div>
              <button class="btn btn-secondary btn-sm" @click="toast('Logo upload isn\'t wired up yet — ask for it if you need it')"><Icon name="upload" :size="12" /> Upload Logo</button>
              <div class="hint">PNG or SVG, at least 256×256px.</div>
            </div>
          </div>
          <div class="field"><label>Full Company Name</label><input v-model="cs.company_name" class="input" /></div>
          <div class="field"><label>Address</label><textarea v-model="cs.company_address" class="input" rows="2" /></div>
          <div class="field"><label>Phone Number</label><input v-model="cs.company_phone" class="input" /></div>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="cash" :size="15" /> Clinic Bank Account Details</h3></div>
        <div class="card-body">
          <div class="field"><label>Bank Name</label><input v-model="cs.bank.name" class="input" /></div>
          <div class="field"><label>Account Name</label><input v-model="cs.bank.accountName" class="input" /></div>
          <div class="field"><label>Account Number</label><input v-model="cs.bank.accountNumber" class="input" /></div>
          <div style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); padding:10px 12px; font-size:11.5px; color:var(--text-700);">
            <Icon name="check-circle" :size="11" /> This information is displayed to patients for IVF installment payments.
          </div>
        </div>
      </div>
    </div>

    <div v-if="cs" class="card" style="margin-top:18px;">
      <div class="card-header"><h3><Icon name="clock" :size="15" /> Clinic Schedule</h3></div>
      <div class="card-body">
        <p class="cell-muted" style="margin-bottom:12px;">Classify each day of the week. A day can be any combination of Consultation, Clinical (scans/bloodwork/monitoring), and Transfers &amp; Surgery — or none of them, which marks it fully closed. Consultation hours only apply on days marked as a Consultation Day.</p>
        <div class="field" style="max-width:260px;">
          <label>Default Appointment Interval</label>
          <select v-model.number="cs.appointment_interval" class="input">
            <option :value="15">15 Minutes</option>
            <option :value="30">30 Minutes</option>
            <option :value="45">45 Minutes</option>
          </select>
        </div>
        <div class="scroll-x" style="margin-top:10px;">
          <table class="data-table">
            <thead><tr><th>Day</th><th>Consultation Day</th><th>Clinical Day</th><th>Transfers &amp; Surgery Day</th><th>Consultation Hours</th></tr></thead>
            <tbody>
              <tr v-for="d in dayNames" :key="d">
                <td class="cell-strong">{{ d }}</td>
                <td><input v-model="cs.schedule[d].consultation" type="checkbox" /></td>
                <td><input v-model="cs.schedule[d].clinical" type="checkbox" /></td>
                <td><input v-model="cs.schedule[d].transfersSurgeries" type="checkbox" /></td>
                <td>
                  <div v-if="cs.schedule[d].consultation" class="flex gap-8">
                    <input v-model="cs.schedule[d].open" class="input" type="time" style="max-width:110px;" />
                    <span class="cell-muted">–</span>
                    <input v-model="cs.schedule[d].close" class="input" type="time" style="max-width:110px;" />
                  </div>
                  <span v-else class="cell-muted">{{ cs.schedule[d].clinical || cs.schedule[d].transfersSurgeries ? 'No consultations' : 'Clinic Closed' }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div v-if="cs" class="flex-between" style="margin-top:18px;">
      <span class="muted" style="font-size:12px;"><Icon name="check-circle" :size="12" /> {{ lastSavedLabel }}</span>
      <div class="flex gap-10">
        <button class="btn btn-secondary" @click="reload">Discard Changes</button>
        <button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save Global Settings</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { toast } = useToast()

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const cs = ref<any>(null)
const saving = ref(false)
const lastSavedLabel = ref('Not saved this session')

async function reload() {
  const { data } = await supabase.from('clinic_settings').select('*').eq('id', 1).single()
  cs.value = data
}
await useAsyncData('admin-settings', reload)

async function save() {
  saving.value = true
  const { error } = await supabase
    .from('clinic_settings')
    .update({
      company_name: cs.value.company_name,
      company_address: cs.value.company_address,
      company_phone: cs.value.company_phone,
      bank: cs.value.bank,
      appointment_interval: cs.value.appointment_interval,
      schedule: cs.value.schedule,
    })
    .eq('id', 1)
  saving.value = false
  if (error) {
    toast('Could not save settings — please try again', 'warn')
    return
  }
  lastSavedLabel.value = 'Last saved: ' + new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
  toast('Global settings saved', 'success')
}
</script>
