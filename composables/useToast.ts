import { reactive } from 'vue'

export type ToastType = 'info' | 'success' | 'warn'
export interface ToastItem {
  id: number
  message: string
  type: ToastType
}

// Module-level (not per-component) so any composable/page can call toast()
// and have it render in the single <ToastStack /> mounted by the layout —
// same single-global-stack behavior as the prototype's #toast-stack div.
const state = reactive<{ items: ToastItem[] }>({ items: [] })
let nextId = 1

export function useToast() {
  function toast(message: string, type: ToastType = 'info') {
    const id = nextId++
    state.items.push({ id, message, type })
    setTimeout(() => {
      const i = state.items.findIndex((t) => t.id === id)
      if (i !== -1) state.items.splice(i, 1)
    }, 3400)
  }

  return { toasts: state.items, toast }
}
