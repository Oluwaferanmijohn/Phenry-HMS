<template>
  <aside class="sidebar">
    <div class="sidebar-brand">
      <div class="mark">P</div>
      <div>
        <div class="name">Phenry Health</div>
        <div class="sub">{{ meta?.subtitle }}</div>
      </div>
    </div>
    <div class="sidebar-section-label">Menu</div>
    <div>
      <template v-for="(item, i) in meta?.nav ?? []" :key="item.id">
        <div v-if="item.section && item.section !== (meta?.nav ?? [])[i - 1]?.section" class="sidebar-section-label">
          {{ item.section }}
        </div>
        <NuxtLink :to="`/${role}/${item.id}`" class="nav-item" :class="{ active: item.id === activePage }">
          <Icon :name="item.icon" :size="16" />
          <span>{{ item.label }}</span>
        </NuxtLink>
      </template>
    </div>
    <div class="sidebar-footer">
      <button v-if="role === 'matron'" class="sidebar-alert-btn" @click="showEmergency = true">
        <Icon name="siren" :size="14" /> Emergency Override
      </button>
      <button v-if="role === 'admin_manager'" class="sidebar-alert-btn" @click="showEmergency = true">
        <Icon name="siren" :size="14" /> Emergency Broadcast
      </button>
      <div class="user-card" title="Sign out" @click="signOut">
        <Avatar :name="displayName" />
        <div class="who">
          <div class="name">{{ displayName }}</div>
          <div class="role">{{ roleLabel }}</div>
        </div>
        <div class="logout"><Icon name="logout" :size="15" /></div>
      </div>
    </div>
  </aside>
  <EmergencyBroadcastModal v-model="showEmergency" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { ROLE_META } from '~/composables/useRoleMeta'
import { signOut as doSignOut, useProfile } from '~/composables/useAuth'

const props = defineProps<{ role: string; activePage: string }>()
const profile = useProfile()
const showEmergency = ref(false)

const meta = computed(() => ROLE_META[props.role])
const displayName = computed(() => profile.value?.full_name || 'Account')
const roleLabel = computed(() => meta.value?.label || props.role)

function signOut() {
  doSignOut()
}
</script>
