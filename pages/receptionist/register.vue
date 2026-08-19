<template>
  <div>
    <div class="page-header"><div><h1>New Patient Registration</h1><div class="desc">Step {{ step }} of 3 — {{ steps[step - 1] }}</div></div></div>

    <div class="card card-pad" style="max-width:700px;">
      <div class="steps" style="margin-bottom:22px;">
        <template v-for="(s, i) in steps" :key="s">
          <div class="step" :class="{ done: i + 1 < step, current: i + 1 === step }">
            <div class="num"><Icon v-if="i + 1 < step" name="check-circle" :size="13" /><template v-else>{{ i + 1 }}</template></div>
            <div class="step-label">{{ s }}</div>
          </div>
          <div v-if="i < steps.length - 1" class="step-line" :class="{ done: i + 1 < step }" />
        </template>
      </div>

      <div v-if="step === 1">
        <b style="font-size:13px;"><Icon name="user" :size="13" /> Personal Identification</b>
        <div class="form-row" style="margin-top:12px;">
          <div class="field"><label>Legal First Name</label><input v-model="draft.first" class="input" placeholder="e.g. Jane" /></div>
          <div class="field"><label>Surname</label><input v-model="draft.last" class="input" placeholder="e.g. Doe" /></div>
        </div>
        <div class="form-row">
          <div class="field"><label>Date of Birth</label><input v-model="draft.dob" class="input" type="date" /></div>
          <div class="field"><label>Assigned Sex at Birth</label><select v-model="draft.sex" class="input"><option>F</option><option>M</option></select></div>
        </div>
      </div>

      <div v-else-if="step === 2">
        <b style="font-size:13px;"><Icon name="phone" :size="13" /> Contact Information</b>
        <div class="form-row" style="margin-top:12px;">
          <div class="field"><label>Primary Phone Number</label><input v-model="draft.phone" class="input" placeholder="(555) 000-0000" /></div>
          <div class="field"><label>Email Address</label><input v-model="draft.email" class="input" placeholder="jane.doe@example.com" /></div>
        </div>
        <div class="field"><label>Home Address</label><textarea v-model="draft.addr" class="input" rows="2" placeholder="Street Address, City, State" /></div>
        <div class="card-pad" style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); margin-top:6px;">
          <b style="font-size:12.5px; color:var(--red-600);">✳ Emergency Contact</b>
          <div class="form-row" style="margin-top:10px;">
            <div class="field"><label>Contact Full Name</label><input v-model="draft.ecName" class="input" placeholder="Contact Name" /></div>
            <div class="field"><label>Relationship</label><input v-model="draft.ecRel" class="input" placeholder="e.g. Spouse, Parent" /></div>
          </div>
          <div class="field"><label>Emergency Phone Number</label><input v-model="draft.ecPhone" class="input" placeholder="(555) 000-0000" /></div>
        </div>
      </div>

      <div v-else>
        <b style="font-size:13px;"><Icon name="clipboard" :size="13" /> Referral Source</b>
        <div class="field" style="margin-top:12px;">
          <label>How did the patient hear about us?</label>
          <select v-model="draft.ref" class="input">
            <option>Instagram Ad</option><option>Google Search</option><option>Physician Referral</option>
            <option>Referral — Friend/Family</option><option>Walk-in</option>
          </select>
        </div>
        <div class="checkbox-row"><input id="rg-consent" v-model="draft.consent" type="checkbox" /><label for="rg-consent">Patient has agreed to the Data Privacy &amp; Medical Consent terms.</label></div>
      </div>

      <div class="flex-between" style="margin-top:22px;">
        <button class="btn btn-secondary" :disabled="step === 1" @click="step--"><Icon name="chevron-left" :size="13" /> Back</button>
        <button v-if="step < 3" class="btn btn-primary" @click="step++">Next <Icon name="arrow-right" :size="13" /></button>
        <button v-else class="btn btn-primary" :disabled="submitting" @click="submit"><Icon name="check-circle" :size="13" /> Complete Registration</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { toast } = useToast()
const router = useRouter()

const steps = ['Personal Details', 'Contact & Emergency', 'Referral']
const step = ref(1)
const submitting = ref(false)

const draft = reactive({
  first: '', last: '', dob: '', sex: 'F',
  phone: '', email: '', addr: '', ecName: '', ecRel: '', ecPhone: '',
  ref: 'Instagram Ad', consent: true,
})

async function submit() {
  if (!draft.first || !draft.last) {
    step.value = 1
    toast('First name and surname are required', 'warn')
    return
  }
  submitting.value = true
  const { data, error } = await supabase.rpc('register_new_patient', {
    p_first: draft.first,
    p_last: draft.last,
    p_dob: draft.dob || '1990-01-01',
    p_sex: draft.sex,
    p_phone: draft.phone,
    p_email: draft.email,
    p_address: draft.addr,
    p_ec_name: draft.ecName,
    p_ec_relationship: draft.ecRel,
    p_ec_phone: draft.ecPhone,
    p_referral_source: draft.ref,
  })
  submitting.value = false

  if (error || !data?.length) {
    toast('Could not register the patient — please try again', 'warn')
    return
  }

  const mrn = data[0].mrn
  toast(`${draft.first} ${draft.last} registered — ${mrn}`, 'success')
  step.value = 1
  Object.assign(draft, { first: '', last: '', dob: '', sex: 'F', phone: '', email: '', addr: '', ecName: '', ecRel: '', ecPhone: '', ref: 'Instagram Ad', consent: true })
  router.push('/receptionist/patients')
}
</script>
