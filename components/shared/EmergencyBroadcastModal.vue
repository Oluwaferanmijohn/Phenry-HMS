<template>
  <Modal :model-value="modelValue" title="Emergency Clinical Broadcast" @update:model-value="$emit('update:modelValue', $event)">
    <div style="background:var(--red-50);border:1px solid var(--red-100);border-radius:var(--radius-sm);padding:12px 14px;margin-bottom:14px;font-size:12.5px;">
      This sends an urgent WhatsApp alert to active doctors, nurses, matrons, and laboratory staff with a phone number on file. Every recipient and delivery result is audited.
    </div>
    <div class="field"><label>Emergency message</label><textarea v-model="message" class="input" rows="5" maxlength="1000" /></div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-danger-solid" :disabled="submitting || message.trim().length < 5" @click="send"><Icon name="siren" :size="13" /> {{ submitting ? 'Sending…' : 'Send Emergency Alert' }}</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [boolean] }>()
const supabase = useSupabaseClient()
const { toast } = useToast()
const message = ref('Emergency response required at Phenry Health. Please acknowledge and contact the clinic immediately.')
const submitting = ref(false)

watch(() => props.modelValue, (open) => {
  if (open && !message.value.trim()) message.value = 'Emergency response required at Phenry Health. Please acknowledge and contact the clinic immediately.'
})

async function send() {
  if (!navigator.onLine) return toast('Emergency broadcasts require a live connection', 'warn')
  submitting.value = true
  try {
    const { data, error } = await supabase.rpc('trigger_emergency_broadcast', { p_message: message.value.trim() })
    if (error) throw error
    const broadcastId = data?.broadcast_id
    const queued = Number(data?.queued || 0)
    if (!broadcastId || queued === 0) {
      toast(`Broadcast recorded, but no staff phone numbers were available (${data?.missing_phone || 0} missing)`, 'warn')
      return
    }
    const { data: result, error: deliveryError } = await supabase.functions.invoke('notify-emergency-broadcast', { body: { broadcast_id: broadcastId } })
    if (deliveryError) throw deliveryError
    toast(`Emergency alert sent to ${result?.sent || 0} staff${result?.failed ? `; ${result.failed} failed` : ''}`, result?.failed ? 'warn' : 'success')
    emit('update:modelValue', false)
  } catch (error: any) {
    toast(error?.message || 'Emergency broadcast could not be delivered', 'warn')
  } finally {
    submitting.value = false
  }
}
</script>
