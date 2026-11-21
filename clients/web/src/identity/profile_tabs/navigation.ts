import { nextTick, type Ref } from 'vue'

export function createProfileTabKeydown<T extends string>(activeTab: Ref<T>, tabs: readonly T[]) {
  return (event: KeyboardEvent): void => {
    const currentIndex = tabs.indexOf(activeTab.value)
    let nextIndex: number
    switch (event.key) {
      case 'ArrowRight': nextIndex = (currentIndex + 1) % tabs.length; break
      case 'ArrowLeft': nextIndex = (currentIndex - 1 + tabs.length) % tabs.length; break
      case 'Home': nextIndex = 0; break
      case 'End': nextIndex = tabs.length - 1; break
      default: return
    }
    event.preventDefault()
    activeTab.value = tabs[nextIndex]
    void nextTick(() => document.getElementById(`profile-tab-${activeTab.value}`)?.focus())
  }
}
