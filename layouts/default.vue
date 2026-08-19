<template>
  <div class="shell">
    <Sidebar :role="role" :active-page="activePage" />
    <div class="main">
      <Topbar :role="role" :active-page="activePage" />
      <div class="content">
        <slot />
      </div>
    </div>
  </div>
  <ToastStack />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useProfile } from '~/composables/useAuth'

const route = useRoute()
const profile = useProfile()

// Route shape is /{role}/{page} for every role (see pages/[role or fixed
// folder]/*.vue) — role also comes from the profile so the sidebar can't be
// spoofed into showing a different role's nav than the one RLS will honor.
const role = computed(() => profile.value?.role ?? (route.path.split('/')[1] || ''))
const activePage = computed(() => route.path.split('/')[2] || '')
</script>
