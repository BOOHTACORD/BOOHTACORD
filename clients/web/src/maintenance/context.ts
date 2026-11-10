import { onMounted, onUnmounted, provide, watch, type InjectionKey } from 'vue'
import { createMaintenanceOwner } from './owner'
import type { createMaintenanceState } from './state'

export const maintenanceStateKey: InjectionKey<ReturnType<typeof createMaintenanceState>> = Symbol('maintenance-state')

export function useMaintenanceOwner(authenticated: () => boolean) {
  const owner = createMaintenanceOwner()
  provide(maintenanceStateKey, owner.state)
  watch(authenticated, value => owner.setAuthenticated(value), { flush: 'sync', immediate: true })
  onMounted(owner.start)
  onUnmounted(owner.stop)
  return owner.state
}
