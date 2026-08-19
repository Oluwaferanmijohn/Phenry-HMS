<template>
  <div class="card stat-card">
    <div class="icon-wrap"><Icon :name="icon" :size="18" /></div>
    <div class="label">{{ label }}</div>
    <div class="value">{{ value }}</div>
    <div v-if="trend" class="trend" :class="trendTone">{{ trend }}</div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{ icon: string; label: string; value: string | number; trend?: string; trendTone?: 'up' | 'down' | 'neutral' }>(),
  { trendTone: 'neutral' }
)
</script>
