<template>
  <div class="progress-track">
    <div class="progress-fill" :class="tone" :style="{ width: Math.max(0, Math.min(100, pct)) + '%' }" />
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ pct: number; tone?: '' | 'green' | 'amber' | 'red' }>(), { tone: '' })
</script>
