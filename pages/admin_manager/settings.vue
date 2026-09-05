<template>
  <div>
    <div class="page-header"><div><h1>Global System Configuration</h1><div class="desc">Manage company profile, clinic-wide financial details, and operational scheduling.</div></div></div>
    <div v-if="cs" class="grid grid-2">
      <div class="card">
        <div class="card-header"><h3><Icon name="building" :size="15" /> Company Profile</h3></div>
        <div class="card-body">
          <div class="flex gap-14" style="align-items:center; margin-bottom:16px;">
            <img v-if="logoUrl" :src="logoUrl" alt="Clinic logo" style="width:60px;height:60px;border-radius:14px;object-fit:contain;background:white;border:1px solid var(--border);" />
            <div v-else style="width:60px;height:60px;border-radius:14px;background:var(--blue-50);color:var(--blue-600);display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:800; flex-shrink:0;">{{ (cs.clinic_name || 'P')[0] }}</div>
            <div>
              <input ref="logoInput" type="file" accept="image/png,image/jpeg,image/webp" hidden @change="uploadLogo" />
              <button class="btn btn-secondary btn-sm" :disabled="uploadingLogo" @click="logoInput?.click()"><Icon name="upload" :size="12" /> {{ uploadingLogo ? 'Uploading…' : 'Upload Logo' }}</button>
              <div class="hint">PNG, JPEG, or WebP; maximum 2 MB.</div>
            </div>
          </div>
          <div class="field"><label>Clinic Name</label><input v-model="cs.clinic_name" class="input" /><div class="hint">Shown to patients throughout the portal and on printed documents.</div></div>
          <div class="field"><label>Clinic Tagline</label><input v-model="cs.clinic_tagline" class="input" placeholder="e.g. Compassionate fertility care, guided by science" /></div>
          <div class="field"><label>Full Company Name</label><input v-model="cs.company_name" class="input" /></div>
          <div class="field"><label>Street Address</label><textarea v-model="cs.company_address" class="input" rows="2" /></div>
          <div class="form-row">
            <div class="field"><label>City</label><input v-model="cs.city" class="input" /></div>
            <div class="field"><label>State / Province</label><input v-model="cs.state" class="input" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Country</label><input v-model="cs.country" class="input" placeholder="Nigeria" /></div>
            <div class="field"><label>Postal Code</label><input v-model="cs.postal_code" class="input" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Primary Phone</label><input v-model="cs.company_phone" class="input" /></div>
            <div class="field"><label>Alternative Phone</label><input v-model="cs.company_phone_alt" class="input" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Official Email</label><input v-model="cs.company_email" class="input" type="email" /></div>
            <div class="field"><label>Website</label><input v-model="cs.company_website" class="input" placeholder="https://..." /></div>
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="shield" :size="15" /> Legal &amp; Laboratory Identity</h3></div>
        <div class="card-body">
          <div class="field"><label>Healthcare Facility Registration Number</label><input v-model="cs.registration_number" class="input" /><div class="hint">Appears on official reports where supplied.</div></div>
          <div class="field"><label>Laboratory Licence / Accreditation Number</label><input v-model="cs.laboratory_license_number" class="input" /></div>
          <div class="field"><label>Tax Identification Number</label><input v-model="cs.tax_identification_number" class="input" /></div>
          <hr class="hr" />
          <div class="field"><label>Laboratory Director / Responsible Professional</label><input v-model="cs.laboratory_director_name" class="input" /></div>
          <div class="field"><label>Professional Title</label><input v-model="cs.laboratory_director_title" class="input" placeholder="e.g. Consultant Pathologist" /></div>
          <div class="field"><label>Official Document Footer</label><textarea v-model="cs.report_footer" class="input" rows="3" placeholder="Optional accreditation, confidentiality, or contact statement." /><div class="hint">Used on printable laboratory reports and can be reused by future invoices, receipts, and letters.</div></div>
        </div>
      </div>
    </div>

    <div v-if="cs" class="card" style="margin-top:18px;">
      <div class="card-header"><h3><Icon name="cash" :size="15" /> Clinic Bank Account Details</h3></div>
      <div class="card-body">
        <div class="form-row-3">
          <div class="field"><label>Bank Name</label><input v-model="cs.bank.name" class="input" /></div>
          <div class="field"><label>Account Name</label><input v-model="cs.bank.accountName" class="input" /></div>
          <div class="field"><label>Account Number</label><input v-model="cs.bank.accountNumber" class="input" /></div>
        </div>
        <div style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); padding:10px 12px; font-size:11.5px; color:var(--text-700);">
          <Icon name="check-circle" :size="11" /> This information is displayed to patients for IVF installment payments.
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
import { computed, ref } from 'vue'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { toast } = useToast()

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const cs = ref<any>(null)
const saving = ref(false)
const uploadingLogo = ref(false)
const logoInput = ref<HTMLInputElement | null>(null)
const lastSavedLabel = ref('Not saved this session')
const logoUrl = computed(() => {
  const path = cs.value?.logo_url
  if (!path) return ''
  if (/^https?:\/\//i.test(path)) return path
  return supabase.storage.from('clinic-assets').getPublicUrl(path).data.publicUrl
})

async function reload() {
  const { data } = await supabase.from('clinic_settings').select('*').eq('id', 1).single()
  cs.value = data
}
await useAsyncData('admin-settings', reload)

async function uploadLogo(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  const allowed = new Set(['image/png', 'image/jpeg', 'image/webp'])
  if (!allowed.has(file.type) || file.size > 2 * 1024 * 1024) {
    toast('Use a PNG, JPEG, or WebP image no larger than 2 MB', 'warn')
    return
  }

  uploadingLogo.value = true
  const extension = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg'
  const path = `branding/${crypto.randomUUID()}.${extension}`
  const oldPath = cs.value?.logo_url as string | undefined
  try {
    const { error: uploadError } = await supabase.storage.from('clinic-assets').upload(path, file, { contentType: file.type, upsert: false })
    if (uploadError) throw uploadError
    const { error: updateError } = await supabase.from('clinic_settings').update({ logo_url: path }).eq('id', 1)
    if (updateError) {
      await supabase.storage.from('clinic-assets').remove([path])
      throw updateError
    }
    cs.value.logo_url = path
    if (oldPath && oldPath !== path && !/^https?:\/\//i.test(oldPath)) await supabase.storage.from('clinic-assets').remove([oldPath])
    toast('Clinic logo updated', 'success')
  } catch {
    toast('Could not upload the logo — please try again', 'warn')
  } finally {
    uploadingLogo.value = false
  }
}

async function save() {
  saving.value = true
  const { error } = await supabase
    .from('clinic_settings')
    .update({
      clinic_name: cs.value.clinic_name,
      company_name: cs.value.company_name,
      company_address: cs.value.company_address,
      company_phone: cs.value.company_phone,
      clinic_tagline: cs.value.clinic_tagline,
      company_phone_alt: cs.value.company_phone_alt,
      company_email: cs.value.company_email,
      company_website: cs.value.company_website,
      city: cs.value.city,
      state: cs.value.state,
      country: cs.value.country,
      postal_code: cs.value.postal_code,
      registration_number: cs.value.registration_number,
      tax_identification_number: cs.value.tax_identification_number,
      laboratory_license_number: cs.value.laboratory_license_number,
      laboratory_director_name: cs.value.laboratory_director_name,
      laboratory_director_title: cs.value.laboratory_director_title,
      report_footer: cs.value.report_footer,
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
