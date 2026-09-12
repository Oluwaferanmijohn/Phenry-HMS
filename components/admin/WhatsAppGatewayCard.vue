<template>
  <div class="card gateway-card">
    <div class="card-header">
      <h3><Icon name="message" :size="15" /> Official WhatsApp</h3>
      <Badge :tone="statusTone">{{ statusLabel }}</Badge>
    </div>
    <div class="card-body">
      <div v-if="loading && !loaded" class="gateway-empty">Checking the hospital WhatsApp connection…</div>
      <div v-else-if="loadError" class="gateway-error">
        <b>WhatsApp setup is unavailable</b>
        <p>{{ loadError }}</p>
        <button class="btn btn-secondary btn-sm" @click="refresh">Try again</button>
      </div>
      <div v-else-if="gateway.status === 'pairing' && gateway.qrDataUrl" class="gateway-pairing">
        <img :src="gateway.qrDataUrl" alt="WhatsApp linked-device pairing QR code" />
        <div>
          <b>Scan with the official hospital phone</b>
          <ol><li>Open WhatsApp on the hospital phone.</li><li>Open Linked devices.</li><li>Tap Link a device and scan this code.</li></ol>
          <p class="muted">The QR refreshes automatically. Do not photograph or share it.</p>
        </div>
      </div>
      <div v-else-if="gateway.status === 'connected'" class="gateway-connected">
        <span class="gateway-check"><Icon name="check-circle" :size="24" /></span>
        <div><b>Hospital WhatsApp is connected</b><p>Cycle reminders can be sent from {{ accountName }}.</p><small v-if="gateway.updatedAt">Last confirmed {{ updatedLabel }}</small></div>
      </div>
      <div v-else class="gateway-offline">
        <b>{{ gateway.status === 'logged_out' ? 'WhatsApp was logged out' : 'Waiting for the WhatsApp service' }}</b>
        <p>{{ gateway.lastError || 'Start the WhatsApp worker on the secure clinic server. A QR code will appear here for the administrator to scan.' }}</p>
        <button class="btn btn-secondary btn-sm" @click="refresh"><Icon name="activity" :size="12" /> Refresh status</button>
      </div>
    </div>
    <div v-if="!compact" class="gateway-security"><Icon name="shield" :size="13" /><span>Only active administrators can view this pairing screen. Session credentials remain on the clinic server.</span></div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
defineProps<{ compact?: boolean }>()
const gateway = ref<any>({ status: 'offline', qrDataUrl: null, accountLabel: null, lastError: null, updatedAt: null })
const loading = ref(false); const loaded = ref(false); const loadError = ref(''); let timer: ReturnType<typeof setInterval> | undefined
const statusLabel = computed(() => ({ pairing: 'Scan QR', connected: 'Connected', disconnected: 'Reconnecting', logged_out: 'Logged out', error: 'Error', offline: 'Offline' }[gateway.value.status as string] || 'Offline'))
const statusTone = computed(() => gateway.value.status === 'connected' ? 'green' : gateway.value.status === 'pairing' ? 'amber' : gateway.value.status === 'error' || gateway.value.status === 'logged_out' ? 'red' : 'gray')
const accountName = computed(() => gateway.value.accountLabel ? String(gateway.value.accountLabel).split(':')[0].split('@')[0] : 'the official account')
const updatedLabel = computed(() => gateway.value.updatedAt ? new Date(gateway.value.updatedAt).toLocaleString() : '')
async function refresh() { loading.value = true; loadError.value = ''; try { gateway.value = await $fetch('/api/admin/whatsapp-status'); loaded.value = true } catch (error: any) { loadError.value = error?.data?.statusMessage || error?.message || 'Could not read the connection status.' } finally { loading.value = false } }
onMounted(() => { void refresh(); timer = setInterval(() => void refresh(), 5000) })
onBeforeUnmount(() => { if (timer) clearInterval(timer) })
</script>

<style scoped>
.gateway-card{overflow:hidden}.gateway-empty,.gateway-error,.gateway-offline{font-size:12px;color:var(--text-600)}.gateway-error p,.gateway-offline p,.gateway-connected p{margin:5px 0 11px;line-height:1.45}.gateway-pairing{display:grid;grid-template-columns:190px 1fr;align-items:center;gap:20px}.gateway-pairing img{width:190px;height:190px;border:1px solid var(--border);border-radius:10px}.gateway-pairing ol{margin:9px 0 8px;padding-left:18px;color:var(--text-700);font-size:12px;line-height:1.7}.gateway-pairing p,.gateway-connected small{font-size:10.5px}.gateway-connected{display:flex;align-items:center;gap:12px}.gateway-check{display:grid;place-items:center;width:44px;height:44px;border-radius:50%;background:var(--green-50);color:var(--green-600)}.gateway-security{display:flex;gap:7px;align-items:center;padding:9px 16px;border-top:1px solid var(--border);background:var(--bg);color:var(--text-500);font-size:10.5px}@media(max-width:620px){.gateway-pairing{grid-template-columns:1fr;text-align:center}.gateway-pairing img{margin:auto}.gateway-pairing ol{text-align:left}}
</style>
