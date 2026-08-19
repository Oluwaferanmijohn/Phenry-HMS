<template>
  <span class="badge" :class="`badge-${tone}`"><slot /></span>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ tone?: 'green' | 'amber' | 'red' | 'blue' | 'purple' | 'gray' }>(), { tone: 'gray' })
</script>
