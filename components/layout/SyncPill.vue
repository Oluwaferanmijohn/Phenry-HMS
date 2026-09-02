<template>
  <div class="sync-pill" :class="{ offline: !displayOnline }" :title="displayOnline ? 'Connected to the server' : 'Offline — supported changes are encrypted locally and will sync automatically'">
    <span class="dot" />
    <span v-if="displayOnline">Connected{{ displayPendingCount ? ` · ${displayPendingCount} pending` : '' }}</span>
    <span v-else>Offline{{ displayPendingCount ? ` · ${displayPendingCount} pending` : '' }}</span>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
// Unlike the prototype's clickable toggle (a demo simulation of going
// offline), this reflects real navigator.onLine + the real pending-write
// queue (see plugins/sync.client.ts) — there's no "pretend offline" affordance
// in production.
const { online, pendingCount } = useSyncQueue()
// The server has no navigator and deliberately renders Offline. Preserve that
// exact state for the client's first hydration render, then reveal the real
// browser connection/queue state after the component mounts.
const mounted = ref(false)
const displayOnline = computed(() => mounted.value && online.value)
const displayPendingCount = computed(() => mounted.value ? pendingCount.value : 0)
onMounted(() => { mounted.value = true })
</script>
