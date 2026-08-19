<template>
  <div style="min-height:100vh; display:flex; align-items:center; justify-content:center; background:var(--bg); padding:20px;">
    <div class="card card-pad" style="max-width:420px; text-align:center;">
      <div class="empty-state" style="padding:10px 0;">
        <div class="icon-wrap"><Icon name="shield" :size="22" /></div>
        <template v-if="profile?.custom_role_key">
          <h4>No screens built for this role yet</h4>
          <p>Your account is correctly set up as a custom role with its own permissions, but this app doesn't have any pages built for custom roles yet — only the fixed ten. Contact your Admin Manager.</p>
        </template>
        <template v-else>
          <h4>No role assigned yet</h4>
          <p>Your account exists but hasn't been assigned a role. Contact your Admin Manager to finish setting up your access.</p>
        </template>
      </div>
      <button class="btn btn-secondary btn-block" style="margin-top:14px;" @click="handleSignOut">Sign out</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { signOut, useProfile } from '~/composables/useAuth'
definePageMeta({ layout: false })
const profile = useProfile()
function handleSignOut() {
  signOut()
}
</script>
