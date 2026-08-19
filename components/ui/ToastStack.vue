<template>
  <Teleport to="body">
    <div class="toast-stack">
      <div v-for="t in toasts" :key="t.id" class="toast" :class="{ success: t.type === 'success', warn: t.type === 'warn' }">
        <span class="dot" :style="{ background: t.type === 'warn' ? 'var(--amber-500)' : t.type === 'success' ? 'var(--green-500)' : 'var(--blue-500)' }" />
        <span>{{ t.message }}</span>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { useToast } from '~/composables/useToast'
const { toasts } = useToast()
</script>
