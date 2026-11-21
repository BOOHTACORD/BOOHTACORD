import { ref } from 'vue'
import { createSystemActivity, type IdleDetectorLike } from './controller'

type DetectorConstructor = {
  new(): IdleDetectorLike
  requestPermission(): Promise<PermissionState>
}
type PolicyDocument = Document & { permissionsPolicy?: { allowsFeature(name: string): boolean } }
const preference = 'boohtacord.system-activity.enabled'

export function createBrowserSystemActivity(report: () => void, reportInactive: () => void = () => {}) {
  const Detector = (window as Window & { IdleDetector?: DetectorConstructor }).IdleDetector
  const mobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
  let available = !!Detector && window.isSecureContext && !mobile
  try { available &&= (document as PolicyDocument).permissionsPolicy?.allowsFeature('idle-detection') ?? true } catch { available = false }
  const enabled = ref(false)
  const source = createSystemActivity({
    available,
    create: () => new Detector!(),
    createInitial: () => new Detector!(),
    permission: () => Detector!.requestPermission(),
    report,
    reportInactive,
    unavailable: () => { enabled.value = false },
    save: value => { try { localStorage.setItem(preference, value ? '1' : '0') } catch { /* Storage is optional. */ } },
  })
  async function enable() { enabled.value = await source.enable(); return enabled.value }
  function disable() { source.disable(); enabled.value = false }
  async function restore() {
    try {
      if (localStorage.getItem(preference) !== '1') return
      enabled.value = await source.restore(async () => (await navigator.permissions.query({ name: 'idle-detection' as PermissionName })).state === 'granted')
    } catch { enabled.value = false }
  }
  function stop() { source.stop(); enabled.value = false }
  return { available, enabled, enable, disable, restore, stop, allowAppInteraction: source.allowAppInteraction, isConfirmedIdle: source.isConfirmedIdle }
}
export type BrowserSystemActivity = ReturnType<typeof createBrowserSystemActivity>
