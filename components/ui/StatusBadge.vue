<template>
  <Badge :tone="statusTone(status) as any">{{ status }}</Badge>
</template>

<script setup lang="ts">
import { statusTone } from '~/composables/useFormat'
defineProps<{ status: string }>()
</script>
