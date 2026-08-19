<template>
  <Modal :model-value="modelValue" :title="patient?.full_name || ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="patient">
      <div class="grid grid-4" style="gap:10px; margin-bottom:14px;">
        <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ patient.patient_id }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(patient.dob) }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patient.blood_group || '—' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="patient.status" /></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;">Contact</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);"><Icon name="phone" :size="11" /> {{ patient.phone || '—' }} &nbsp; <Icon name="mail" :size="11" /> {{ patient.email || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700);">{{ patient.address || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700); margin-top:4px;">Emergency: {{ patient.emergency_contact?.name || '—' }} ({{ patient.emergency_contact?.relationship || '—' }}) · {{ patient.emergency_contact?.phone || '—' }}</p>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="clipboard" :size="12" /> Medical History</b>
      <div class="grid grid-3" style="margin-top:8px; gap:10px;">
        <div><div class="muted" style="font-size:10.5px;">ALLERGIES</div><div style="font-weight:600; font-size:12.5px;" :style="{ color: patient.allergies?.length ? 'var(--red-600)' : 'var(--text-900)' }">{{ patient.allergies?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">CHRONIC CONDITIONS</div><div style="font-weight:600; font-size:12.5px;">{{ patient.chronic_conditions?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">OBSTETRIC HISTORY</div><div style="font-weight:600; font-size:12.5px;">{{ patient.obstetric_history || '—' }}</div></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="layers" :size="12" /> Treatment Cycle</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
        {{ cycle ? `${cycle.type} — ${cycle.stage} (Day ${cycle.cycle_day}) · ${cycle.protocol}` : 'No active treatment cycle.' }}
      </p>
      <template v-if="patient.spouse">
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="user" :size="12" /> Spouse / Partner</b>
        <div class="grid grid-3" style="margin-top:8px; gap:10px;">
          <div><div class="muted" style="font-size:10.5px;">NAME</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.name || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.bloodGroup || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">SFA RESULT</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.sfa || 'Not on file' }}</div></div>
        </div>
      </template>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="message" :size="12" /> Past Consultations</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:8px;">
        <p v-if="!consultations.length" class="muted" style="font-size:12px;">No past consultations on file.</p>
        <div v-for="c in consultations" :key="c.id" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm);">
          <div class="flex-between"><b style="font-size:12px;">{{ fmtDate(c.date) }} · {{ c.type }}</b><span class="cell-muted">{{ c.provider_name }}</span></div>
          <p style="font-size:12px; color:var(--text-700); margin-top:6px;">{{ c.notes }}</p>
          <p class="cell-muted" style="margin-top:4px;">Dx: {{ c.diagnosis }}</p>
        </div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="flask" :size="12" /> Past Tests</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!labResults.length" class="muted" style="font-size:12px;">No lab results on file yet.</p>
        <div v-for="r in labResults" :key="r.id" class="list-row" style="padding:6px 0;">
          <div><div class="main-txt">{{ r.lab_templates?.name || 'External Upload' }}</div><div class="sub-txt">{{ fmtDate(r.collected_on) }}</div></div>
        </div>
      </div>
    </template>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button>
      <button v-if="caps.allowLabActions" class="btn btn-secondary" @click="$emit('upload-external')"><Icon name="upload" :size="13" /> Upload External Result</button>
      <button v-if="caps.allowConsultation" class="btn btn-primary" @click="$emit('start-consultation')"><Icon name="clipboard" :size="13" /> Start Consultation</button>
      <button v-if="caps.allowVisitDoc" class="btn btn-primary" @click="$emit('go-to-visit')"><Icon name="clipboard" :size="13" /> Go to Visit Documentation</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { fmtDate, computeAge } from '~/composables/useFormat'

defineProps<{
  modelValue: boolean
  patient: any | null
  cycle: any | null
  consultations: any[]
  labResults: any[]
  caps: { allowConsultation?: boolean; allowVisitDoc?: boolean; allowLabActions?: boolean }
}>()
defineEmits<{ 'update:modelValue': [boolean]; 'upload-external': []; 'start-consultation': []; 'go-to-visit': [] }>()
</script>
