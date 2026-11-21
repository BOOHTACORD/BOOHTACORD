import { onBeforeUnmount, onMounted } from 'vue'
import type { ActionScope } from '../../telemetry/action_scope/scope'
import { observeWorkspace } from '../../telemetry/observe_render/workspace'

interface WorkspaceReadyPorts {
  readiness?: ActionScope
  beforeStart?: Promise<void>
  start(): void
  refresh(): Promise<unknown>
  failed(): boolean
  stop(): void
}

export function bindWorkspaceReady(ports: WorkspaceReadyPorts): void {
  let mounted = true, started = false
  let timer: ReturnType<typeof setTimeout> | null = null
  function start() {
    if (!mounted || started) return
    started = true
    if (timer !== null) clearTimeout(timer)
    timer = null
    ports.start()
    void observeWorkspace(ports.readiness, async () => { await ports.refresh() },
      () => mounted, ports.failed)
  }
  onMounted(() => {
    if (!ports.beforeStart) { start(); return }
    timer = setTimeout(start, 2_000)
    void ports.beforeStart.then(start, start)
  })
  onBeforeUnmount(() => {
    mounted = false
    if (timer !== null) clearTimeout(timer)
    ports.readiness?.finish('cancelled', 'disposed')
    ports.stop()
  })
}
