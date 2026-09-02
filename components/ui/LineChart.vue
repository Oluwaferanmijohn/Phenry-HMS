<template>
  <svg :viewBox="`0 0 ${w} ${h + 24}`" width="100%" :height="h + 24">
    <defs>
      <linearGradient :id="gradId" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#1479B8" stop-opacity="0.22" />
        <stop offset="100%" stop-color="#1479B8" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path :d="area" :fill="`url(#${gradId})`" />
    <path :d="path" fill="none" stroke="#1479B8" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
    <circle v-for="(p, i) in points" :key="i" :cx="p[0]" :cy="p[1]" r="3.2" fill="#1479B8" />
    <text v-for="(d, i) in data" :key="'t' + i" :x="i * stepX" :y="h + 18" font-size="10.5" fill="#98A2B3" text-anchor="middle">{{ d.m }}</text>
  </svg>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance } from 'vue'

const props = withDefaults(defineProps<{ data: { m: string; v: number }[]; w?: number; h?: number }>(), { w: 560, h: 180 })
const gradId = `areaGrad-${getCurrentInstance()?.uid ?? 'chart'}`

const max = computed(() => Math.max(...props.data.map((d) => d.v), 1) * 1.15)
const stepX = computed(() => props.w / Math.max(1, props.data.length - 1))
const points = computed(() => props.data.map((d, i) => [i * stepX.value, props.h - (d.v / max.value) * (props.h - 20) - 6]))
const path = computed(() => points.value.map((p, i) => (i === 0 ? 'M' : 'L') + p[0] + ',' + p[1]).join(' '))
const area = computed(() => `${path.value} L${props.w},${props.h} L0,${props.h} Z`)
</script>
