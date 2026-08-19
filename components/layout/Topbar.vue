<template>
  <div class="topbar">
    <div class="breadcrumb"><b>{{ meta?.label }}</b> <span>/</span> <span>{{ activeLabel }}</span></div>
    <div class="search-box">
      <Icon name="search" :size="14" />
      <input placeholder="Search patients, records, or IDs…" />
    </div>
    <SyncPill />
    <button class="icon-btn" @click="toast('No new notifications right now')">
      <Icon name="bell" :size="15" /><span class="icon-dot" />
    </button>
    <button class="icon-btn" @click="toast('Settings are managed by your Admin Manager')">
      <Icon name="settings" :size="15" />
    </button>
    <div class="topbar-user">
      <Avatar :name="displayName" :size="32" />
      <div class="who">
        <div class="name">{{ displayName }}</div>
        <div class="role">{{ roleLabel }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { ROLE_META } from '~/composables/useRoleMeta'
import { useToast } from '~/composables/useToast'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ role: string; activePage: string }>()
const { toast } = useToast()
const profile = useProfile()

const meta = computed(() => ROLE_META[props.role])
const activeLabel = computed(() => meta.value?.nav.find((n) => n.id === props.activePage)?.label ?? '')
const displayName = computed(() => profile.value?.full_name || 'Account')
const roleLabel = computed(() => meta.value?.label || props.role)
</script>
