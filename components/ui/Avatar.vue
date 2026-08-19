<template>
  <div class="avatar" :style="{ width: size + 'px', height: size + 'px', fontSize: size * 0.38 + 'px' }">
    {{ initials(name) }}
  </div>
</template>

<script setup lang="ts">
import { initials } from '~/composables/useFormat'
withDefaults(defineProps<{ name: string; size?: number }>(), { size: 34 })
</script>
