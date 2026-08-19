<template>
  <div class="sync-pill" :class="{ offline: !online }" :title="online ? 'Connected — changes save immediately' : 'Offline — changes are saved locally and will sync automatically'">
    <span class="dot" />
    <span v-if="online">Offline Sync Ready</span>
    <span v-else>Offline{{ pendingCount ? ` · ${pendingCount} pending` : '' }}</span>
  </div>
</template>

<script setup lang="ts">
import { useSyncQueue } from '~/composables/useSyncQueue'
// Unlike the prototype's clickable toggle (a demo simulation of going
// offline), this reflects real navigator.onLine + the real pending-write
// queue (see plugins/sync.client.ts) — there's no "pretend offline" affordance
// in production.
const { online, pendingCount } = useSyncQueue()
</script>
