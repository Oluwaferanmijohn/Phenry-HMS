<template>
  <svg :viewBox="`0 0 ${size} ${size}`" :width="size" :height="size">
    <circle
      v-for="(a, i) in arcs"
      :key="i"
      :cx="size / 2"
      :cy="size / 2"
      :r="r"
      fill="none"
      :stroke="a.color"
      stroke-width="16"
      :stroke-dasharray="`${a.len} ${circ - a.len}`"
      :stroke-dashoffset="-a.offset"
      :transform="`rotate(-90 ${size / 2} ${size / 2})`"
    />
  </svg>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{ segments: { pct: number; color: string; label?: string }[]; size?: number }>(), { size: 150 })
const r = computed(() => props.size / 2 - 14)
const circ = computed(() => 2 * Math.PI * r.value)

const arcs = computed(() => {
  let offset = 0
  return props.segments.map((s) => {
    const len = (s.pct / 100) * circ.value
    const arc = { len, offset, color: s.color }
    offset += len
    return arc
  })
})
</script>
