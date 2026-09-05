<template>
  <div>
    <div class="page-header">
      <div><h1>Fertility Procedures &amp; Cryostorage</h1><div class="desc">One workspace for OPU, IUI, embryo transfer, fertility-lab procedure reports, and frozen embryo, egg, and sperm storage.</div></div>
      <div class="page-actions">
        <button v-if="role === 'chief_embryologist'" class="btn btn-secondary" @click="openTank(null)"><Icon name="plus" :size="13" /> Add Storage Tank</button>
        <button class="btn btn-primary" @click="openNewStorage()"><Icon name="snow" :size="13" /> Store Frozen Specimen</button>
      </div>
    </div>

    <div class="workspace-tabs">
      <button :class="{ active: tab === 'procedures' }" @click="tab = 'procedures'"><Icon name="calendar" :size="14" /><span>Procedure Queue</span><Badge tone="blue">{{ activeProcedureCount }}</Badge></button>
      <button :class="{ active: tab === 'storage' }" @click="tab = 'storage'"><Icon name="snow" :size="14" /><span>Cryostorage Inventory</span><Badge tone="green">{{ storedSpecimenCount }}</Badge></button>
    </div>

    <template v-if="tab === 'procedures'">
      <div class="source-note"><Icon name="check-circle" :size="14" /><span>This queue now reads the real Doctor and Matron procedure schedule. Legacy transfer/cryo entries are also kept visible.</span></div>
      <div class="filter-row">
        <button v-for="option in filters" :key="option.key" :class="['filter-button', { active: filter === option.key }]" @click="filter = option.key">{{ option.label }} <span>{{ option.count }}</span></button>
      </div>
      <div class="card procedure-card">
        <table class="data-table">
          <thead><tr><th>Date &amp; Time</th><th>Patient</th><th>Fertility Procedure</th><th>Provider / Location</th><th>Status</th><th>Documentation</th></tr></thead>
          <tbody>
            <tr v-for="item in filteredProcedures" :key="`${item.source}-${item.id}`">
              <td><b>{{ fmtDate(item.scheduled_date) }}</b><div class="cell-muted">{{ item.time ? formatTime12(item.time) : 'Time not recorded' }}</div></td>
              <td><button class="patient-link" @click="openPatient(item)">{{ item.patient_name }}<small>{{ item.patient_id }}</small></button></td>
              <td><Badge tone="blue">{{ item.type }}</Badge><div class="cell-muted source-label">{{ item.source === 'clinical' ? 'Doctor / Matron schedule' : 'Legacy lab schedule' }}</div></td>
              <td><span>{{ item.provider_name || 'Unassigned' }}</span><div class="cell-muted">{{ item.location || 'Location not recorded' }}</div></td>
              <td><StatusBadge :status="item.status" /></td>
              <td>
                <div class="action-stack">
                  <button v-if="item.source === 'clinical'" class="btn btn-primary btn-sm" @click="openReport(item)"><Icon name="file" :size="11" /> {{ item.report_status === 'Completed' ? 'View / Amend Report' : item.report_status === 'Draft' ? 'Continue Report' : 'Enter Report' }}</button>
                  <template v-else>
                    <button v-if="['Scheduled','Postponed'].includes(item.status)" class="btn btn-primary btn-sm" @click="openLegacyAction(item, 'Done')">Document Outcome</button>
                    <button class="btn btn-secondary btn-sm" @click="viewLegacyDocumentation(item)"><Icon name="file" :size="11" /> View Notes</button>
                  </template>
                  <button v-if="procedureSupportsCryo(item.type)" class="btn btn-secondary btn-sm" @click="openStorageFromProcedure(item)"><Icon name="snow" :size="11" /> Record Storage</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filteredProcedures.length" style="padding:26px;"><EmptyState icon="calendar" title="No fertility procedures in this view" description="OPU, IUI, embryo transfer, sperm procedures, and freezing scheduled by Doctor or Matron will appear here." /></div>
      </div>
    </template>

    <template v-else>
      <div class="tank-grid">
        <div v-for="tank in tanks" :key="tank.id" class="card tank-card" :class="{ clickable: role === 'chief_embryologist' }" @click="role === 'chief_embryologist' && openTank(tank)">
          <div class="flex-between"><b>{{ tank.name }}</b><Badge :tone="tank.used / Math.max(1,tank.capacity) > .85 ? 'red' : 'blue'">{{ Math.round(tank.used / Math.max(1,tank.capacity) * 100) }}%</Badge></div>
          <p>{{ tank.phase }} · {{ tank.current_temp }}°C</p><ProgressBar :pct="tank.used / Math.max(1,tank.capacity) * 100" :tone="tank.used / Math.max(1,tank.capacity) > .85 ? 'red' : ''" /><small>{{ tank.used }} of {{ tank.capacity }} storage units used</small>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="snow" :size="15" /> Frozen Specimen Register</h3><div class="search-box"><Icon name="search" :size="12" /><input v-model="storageSearch" placeholder="Patient, label, tank, location…" /></div></div>
        <table class="data-table">
          <thead><tr><th>Patient / Specimen</th><th>Frozen</th><th>Quantity</th><th>Exact Storage Location</th><th>Quality / Method</th><th>Status</th><th></th></tr></thead>
          <tbody>
            <tr v-for="record in filteredStorage" :key="record.id">
              <td><b>{{ record.patient_name }}</b><div class="cell-muted">{{ record.patient_id }} · {{ record.asset_type }}</div></td>
              <td class="cell-muted">{{ fmtDate(record.freezing_date) }}</td>
              <td>{{ record.straws }} {{ record.storage_unit_type || 'Straw' }}<span v-if="record.straws !== 1">s</span><div v-if="record.per_straw" class="cell-muted">{{ record.per_straw }} specimen(s) each</div></td>
              <td><b class="mono location-code">{{ record.tank_name || 'No tank' }} / {{ record.canister || '—' }} / {{ record.cane || '—' }} / {{ record.goblet || '—' }} / {{ record.position || '—' }}</b><div class="cell-muted">{{ record.rack ? `${record.rack} · ` : '' }}Label: {{ record.container_label || 'Not recorded' }}</div></td>
              <td><span>{{ record.specimen_quality || '—' }}</span><div class="cell-muted">{{ record.freeze_method || 'Method not recorded' }}</div></td>
              <td><Badge :tone="record.status === 'Stored' ? 'green' : 'gray'">{{ record.status }}</Badge></td>
              <td><div class="action-stack"><button v-if="record.status === 'Stored'" class="btn btn-secondary btn-sm" @click="editStorage(record)"><Icon name="edit" :size="11" /> Edit Location</button><button v-if="record.status === 'Stored'" class="btn btn-secondary btn-sm" @click="openUse(record)">Use / Remove</button></div></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filteredStorage.length" style="padding:24px;"><EmptyState icon="snow" title="No frozen specimens found" description="Store embryos, oocytes, or sperm with their exact tank and container location." /></div>
      </div>
    </template>

    <FertilityProcedureReportModal v-model="showReport" :schedule="activeProcedure" @saved="load" @store-specimen="openStorageFromProcedure" />
    <CryoLogModal v-model="showStorage" :tanks="tanks" :record="activeStorage" :preselected-patient-id="storagePatientId" :source-procedure-id="storageProcedureId" :default-asset-type="storageAssetType" @logged="load" />
    <TankModal v-if="role === 'chief_embryologist'" v-model="showTank" :tank="activeTank" @saved="load" />
    <PatientDetailModal v-model="showPatient" :patient="patientDetail" :cycle="null" :consultations="[]" :lab-results="[]" :caps="{}" @open-spouse="$router.push(`/${role}/patients?patient=${$event}&linkedFrom=${patientDetail.patient_id}`)" />

    <Modal v-model="showLegacyAction" :title="`Document ${activeProcedure?.type || 'Procedure'}`">
      <p v-if="activeProcedure" class="cell-muted" style="margin-bottom:12px;">{{ activeProcedure.patient_name }} · {{ fmtDate(activeProcedure.scheduled_date) }}</p>
      <div v-if="legacyAction === 'Postponed'" class="field"><label>New Date</label><input v-model="newDate" class="input" type="date" /></div>
      <div v-if="legacyAction === 'Done' && isActiveTransfer" class="field"><label>Embryos Transferred</label><input v-model="embryosUsed" class="input" type="number" min="1" /></div>
      <div class="field"><label>Procedure Outcome / Reason</label><textarea v-model="legacyNotes" class="input" rows="4" /></div>
      <template #footer><button class="btn btn-secondary" @click="showLegacyAction=false">Cancel</button><button class="btn btn-primary" @click="saveLegacyAction">Save Documentation</button></template>
    </Modal>
    <Modal v-model="showLegacyDoc" :title="activeProcedure?.type || 'Procedure Notes'"><p class="cell-muted">{{ activeProcedure?.patient_name }} · {{ activeProcedure ? fmtDate(activeProcedure.scheduled_date) : '' }}</p><p style="margin-top:12px; white-space:pre-wrap;">{{ activeProcedure?.notes || 'No documentation recorded.' }}</p><template #footer><button class="btn btn-secondary" @click="showLegacyDoc=false">Close</button></template></Modal>
    <Modal v-model="showUse" title="Use or Remove Frozen Specimen"><p v-if="activeStorage" class="cell-muted">{{ activeStorage.patient_name }} · {{ activeStorage.asset_type }} · {{ activeStorage.straws }} unit(s) stored</p><div class="field" style="margin-top:12px;"><label>Units Used / Removed</label><input v-model="useQty" class="input" type="number" min="1" :max="activeStorage?.straws" /></div><template #footer><button class="btn btn-secondary" @click="showUse=false">Cancel</button><button class="btn btn-primary" @click="confirmUse">Confirm</button></template></Modal>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'
import { isFertilityLabProcedure, procedureCategory, procedureSupportsCryo } from '~/composables/useFertilityProcedures'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const props = withDefaults(defineProps<{ role: string; initialTab?: 'procedures' | 'storage' }>(), { initialTab: 'procedures' })
const supabase = useSupabaseClient(); const { queueOrRun } = useSyncQueue(); const { toast } = useToast()
const tab = ref(props.initialTab); const filter = ref<'active'|'today'|'all'|'completed'>('active'); const storageSearch = ref('')
const procedures = ref<any[]>([]); const tanks = ref<any[]>([]); const storageRecords = ref<any[]>([])

async function load() {
  const [clinicalRes, legacyRes, tanksRes, storageRes, reportsRes] = await Promise.all([
    supabase.from('surgery_schedule').select('*, patient_names(full_name), profiles:assigned_provider_id(full_name)').order('date', { ascending: true }).order('time', { ascending: true }),
    supabase.from('transfer_cryo_schedule').select('*, patient_names(full_name), profiles:documented_by(full_name)').order('scheduled_date', { ascending: true }),
    supabase.from('cryo_tanks').select('*').order('name'),
    supabase.from('cryo_records').select('*, patient_names(full_name), cryo_tanks(name)').order('freezing_date', { ascending: false }),
    supabase.from('fertility_procedure_reports').select('schedule_id,status'),
  ])
  const reportMap = new Map((reportsRes.data || []).map((report:any) => [report.schedule_id, report.status]))
  const clinical = (clinicalRes.data || []).filter((row:any) => isFertilityLabProcedure(row.procedure)).map((row:any) => ({ ...row, source:'clinical', type:row.procedure, scheduled_date:row.date, patient_name:row.patient_names?.full_name || 'Unknown', provider_name:row.profiles?.full_name || '', report_status:reportMap.get(row.id) || '' }))
  const legacy = (legacyRes.data || []).map((row:any) => ({ ...row, source:'legacy', patient_name:row.patient_names?.full_name || 'Unknown', provider_name:row.profiles?.full_name || '' }))
  procedures.value = [...clinical, ...legacy].sort((a,b) => `${a.scheduled_date} ${a.time || ''}`.localeCompare(`${b.scheduled_date} ${b.time || ''}`))
  tanks.value = tanksRes.data || []
  storageRecords.value = (storageRes.data || []).map((row:any) => ({ ...row, patient_name:row.patient_names?.full_name || 'Unknown', tank_name:row.cryo_tanks?.name || '' }))
}
await useAsyncData(`embryology-procedure-workspace-${props.role}`, load)

const today = new Date().toISOString().slice(0,10)
const activeProcedureCount = computed(() => procedures.value.filter(row => ['Scheduled','Postponed','Draft'].includes(row.status) || !['Completed','Done','Cancelled'].includes(row.status)).length)
const storedSpecimenCount = computed(() => storageRecords.value.filter(row => row.status === 'Stored').reduce((sum,row) => sum + Number(row.straws || 0),0))
const filters = computed(() => [
  { key:'active' as const,label:'Active queue',count:procedures.value.filter(row => !['Completed','Done','Cancelled'].includes(row.status)).length },
  { key:'today' as const,label:'Today',count:procedures.value.filter(row => row.scheduled_date === today).length },
  { key:'all' as const,label:'All procedures',count:procedures.value.length },
  { key:'completed' as const,label:'Completed',count:procedures.value.filter(row => ['Completed','Done'].includes(row.status)).length },
])
const filteredProcedures = computed(() => procedures.value.filter(row => filter.value === 'all' || (filter.value === 'today' ? row.scheduled_date === today : filter.value === 'completed' ? ['Completed','Done'].includes(row.status) : !['Completed','Done','Cancelled'].includes(row.status))))
const filteredStorage = computed(() => { const q=storageSearch.value.trim().toLowerCase(); return storageRecords.value.filter(row => !q || `${row.patient_name} ${row.patient_id} ${row.asset_type} ${row.tank_name} ${row.canister} ${row.rack} ${row.cane} ${row.goblet} ${row.position} ${row.container_label}`.toLowerCase().includes(q)) })

const showReport=ref(false), activeProcedure=ref<any>(null), showStorage=ref(false), activeStorage=ref<any>(null), storagePatientId=ref(''), storageProcedureId=ref(''), storageAssetType=ref<'Embryo'|'Oocyte'|'Sperm'>('Embryo')
function openReport(item:any){activeProcedure.value=item;showReport.value=true}
function inferredAsset(type:string){const category=procedureCategory(type);return category==='sperm'?'Sperm':category==='opu'?'Oocyte':'Embryo'}
function openNewStorage(){activeStorage.value=null;storagePatientId.value='';storageProcedureId.value='';storageAssetType.value='Embryo';showStorage.value=true;tab.value='storage'}
function openStorageFromProcedure(item:any){activeStorage.value=null;storagePatientId.value=item.patient_id;storageProcedureId.value=item.source==='clinical'?item.id:'';storageAssetType.value=inferredAsset(item.type);showStorage.value=true;tab.value='storage'}
function editStorage(record:any){activeStorage.value=record;storagePatientId.value=record.patient_id;storageProcedureId.value=record.source_procedure_id || '';storageAssetType.value=record.asset_type;showStorage.value=true}

const showTank=ref(false),activeTank=ref<any>(null);function openTank(tank:any){activeTank.value=tank;showTank.value=true}
const showPatient=ref(false),patientDetail=ref<any>(null)
async function openPatient(item:any){if(props.role==='lab_tech'){const{data}=await supabase.rpc('patient_lab_profile',{p_patient_id:item.patient_id});patientDetail.value=data?.[0]||null}else{const{data}=await supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id',item.patient_id).single();patientDetail.value=data?{...data,full_name:data.patient_names?.full_name}:null}showPatient.value=true}

const showLegacyAction=ref(false),showLegacyDoc=ref(false),legacyAction=ref('Done'),legacyNotes=ref(''),newDate=ref(''),embryosUsed=ref<number|string>('')
const isActiveTransfer=computed(() => String(activeProcedure.value?.type||'').toLowerCase().includes('transfer'))
function openLegacyAction(item:any,action:string){activeProcedure.value=item;legacyAction.value=action;legacyNotes.value='';newDate.value=item.scheduled_date;embryosUsed.value='';showLegacyAction.value=true}
function viewLegacyDocumentation(item:any){activeProcedure.value=item;showLegacyDoc.value=true}
async function saveLegacyAction(){if(!activeProcedure.value||!legacyNotes.value.trim())return toast('Procedure outcome documentation is required.','warn');if(isActiveTransfer.value&&Number(embryosUsed.value)<1)return toast('Enter the number of embryos transferred.','warn');await queueOrRun(`${activeProcedure.value.type} documented`,{kind:'rpc',rpcName:'document_transfer_cryo_event',payload:{p_event_id:activeProcedure.value.id,p_action:legacyAction.value,p_notes:legacyNotes.value,p_new_date:legacyAction.value==='Postponed'?newDate.value:null,p_embryos_used:isActiveTransfer.value?Number(embryosUsed.value):null,p_deduct_cryo:false}},()=>void load());showLegacyAction.value=false}

const showUse=ref(false),useQty=ref<number|string>(1)
function openUse(record:any){activeStorage.value=record;useQty.value=record.straws;showUse.value=true}
async function confirmUse(){if(!activeStorage.value||Number(useQty.value)<1||Number(useQty.value)>activeStorage.value.straws)return toast('Enter a valid number of units.','warn');await queueOrRun('Cryogenic storage usage recorded',{kind:'rpc',rpcName:'use_cryo_record',payload:{p_record_id:activeStorage.value.id,p_straws_used:Number(useQty.value)}},()=>void load());showUse.value=false}
</script>

<style scoped>
.workspace-tabs{display:flex;gap:8px;margin-bottom:15px}.workspace-tabs button{display:flex;align-items:center;gap:8px;padding:10px 13px;border:1px solid var(--border);border-radius:9px;background:#fff;font:inherit;font-size:12px;font-weight:700;color:var(--text-600)}.workspace-tabs button.active{border-color:var(--blue-500);background:var(--blue-50);color:var(--blue-700)}
.source-note{display:flex;align-items:center;gap:8px;margin-bottom:12px;padding:9px 11px;border-radius:8px;background:var(--green-50);color:var(--green-700);font-size:11.5px}.filter-row{display:flex;gap:7px;margin-bottom:11px;flex-wrap:wrap}.filter-button{padding:7px 10px;border:1px solid var(--border);border-radius:7px;background:#fff;font:inherit;font-size:11px;color:var(--text-600)}.filter-button span{margin-left:4px;font-weight:800}.filter-button.active{border-color:var(--blue-500);background:var(--blue-50);color:var(--blue-700)}
.procedure-card{overflow-x:auto}.patient-link{padding:0;border:0;background:none;text-align:left;font:inherit;font-weight:700;color:var(--blue-700);cursor:pointer}.patient-link small{display:block;margin-top:2px;color:var(--text-500);font-weight:400}.source-label{margin-top:4px;font-size:9.5px}.action-stack{display:flex;align-items:flex-start;gap:5px;flex-wrap:wrap}.tank-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:14px}.tank-card{padding:14px}.tank-card p,.tank-card small{display:block;margin:5px 0;color:var(--text-500);font-size:10.5px}.location-code{font-size:11px}.search-box{max-width:260px}
@media(max-width:900px){.tank-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.workspace-tabs{flex-direction:column}.tank-grid{grid-template-columns:1fr}}
</style>
