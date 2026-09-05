<template>
  <div class="patient-photo-picker">
    <div class="patient-photo-preview">
      <img v-if="previewUrl" :src="previewUrl" alt="Selected patient picture" />
      <Avatar v-else :name="patientName || 'Patient'" :size="72" />
    </div>
    <div>
      <input ref="fileInput" class="sr-photo-input" type="file" accept="image/jpeg,image/png,image/webp" capture="environment" @change="choosePhoto" />
      <button type="button" class="btn btn-secondary btn-sm" @click="fileInput?.click()">
        <Icon name="camera" :size="13" /> {{ modelValue ? 'Change picture' : 'Take or upload picture' }}
      </button>
      <button v-if="modelValue" type="button" class="photo-remove" @click="clearPhoto">Remove</button>
      <p>JPEG, PNG, or WebP · maximum 5 MB</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { validatePatientPhoto } from '~/composables/usePatientPhoto'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ modelValue: File | null; patientName?: string }>()
const emit = defineEmits<{ 'update:modelValue': [File | null] }>()
const { toast } = useToast()
const fileInput = ref<HTMLInputElement | null>(null)
const previewUrl = ref('')

function replacePreview(file: File | null) {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  previewUrl.value = file ? URL.createObjectURL(file) : ''
}

function choosePhoto(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  if (!file) return
  const error = validatePatientPhoto(file)
  if (error) {
    toast(error, 'warn')
    input.value = ''
    return
  }
  replacePreview(file)
  emit('update:modelValue', file)
}

function clearPhoto() {
  replacePreview(null)
  if (fileInput.value) fileInput.value.value = ''
  emit('update:modelValue', null)
}

watch(() => props.modelValue, (file) => {
  if (!file && previewUrl.value) replacePreview(null)
})
onBeforeUnmount(() => { if (previewUrl.value) URL.revokeObjectURL(previewUrl.value) })
</script>

<style scoped>
.patient-photo-picker { display:flex; align-items:center; gap:14px; padding:12px; border:1px dashed var(--border-strong); border-radius:var(--radius-sm); background:var(--bg); }
.patient-photo-preview { width:76px; height:76px; flex:0 0 76px; overflow:hidden; border:3px solid #fff; border-radius:50%; box-shadow:0 0 0 1px var(--border); background:#fff; }
.patient-photo-preview img { width:100%; height:100%; object-fit:cover; }
.sr-photo-input { position:absolute; width:1px; height:1px; overflow:hidden; opacity:0; pointer-events:none; }
.photo-remove { margin-left:9px; border:0; background:transparent; color:var(--red-600); font:inherit; font-size:11px; font-weight:650; cursor:pointer; }
.patient-photo-picker p { margin-top:6px; color:var(--text-500); font-size:10.5px; }
@media (max-width:520px) { .patient-photo-picker { align-items:flex-start; } }
</style>
