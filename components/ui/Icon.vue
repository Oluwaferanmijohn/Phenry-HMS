<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.8"
    stroke-linecap="round"
    stroke-linejoin="round"
    v-html="path"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { ICONS } from '~/composables/useIcons'

const props = withDefaults(defineProps<{ name: string; size?: number }>(), { size: 18 })
const path = computed(() => ICONS[props.name] ?? ICONS.grid)
</script>
