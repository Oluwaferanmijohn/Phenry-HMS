<template>
  <div />
</template>

<script setup lang="ts">
// All the real redirect logic lives in middleware/auth.global.ts (it runs
// before this page's own script ever executes) — this file exists only so
// Nuxt has something to route "/" to.
definePageMeta({ layout: false })
</script>
