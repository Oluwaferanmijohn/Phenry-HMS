<template>
  <div class="empty-state">
    <div class="icon-wrap"><Icon :name="icon" :size="22" /></div>
    <h4>{{ title }}</h4>
    <p>{{ description }}</p>
  </div>
</template>

<script setup lang="ts">
defineProps<{ icon: string; title: string; description: string }>()
</script>
