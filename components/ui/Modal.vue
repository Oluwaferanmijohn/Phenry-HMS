<template>
  <Teleport to="body">
    <div v-if="modelValue" class="modal-overlay" @mousedown.self="close">
      <div class="modal" :class="{ wide }">
        <div class="modal-head">
          <h3>{{ title }}</h3>
          <button class="modal-close" @click="close"><Icon name="x-circle" :size="16" /></button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
        <div v-if="$slots.footer" class="modal-foot">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ modelValue: boolean; title: string; wide?: boolean }>(), { wide: false })
const emit = defineEmits<{ 'update:modelValue': [boolean] }>()
function close() {
  emit('update:modelValue', false)
}
</script>
