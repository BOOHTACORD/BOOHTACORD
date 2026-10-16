import '../../src/style.css'
import { clearWorkspaceDrawerHistory, restoreWorkspaceDrawerState, syncWorkspaceDrawerHistory, type WorkspaceHistoryView } from '../../src/workspace/workspace_drawer_history'

const root = document.querySelector<HTMLDivElement>('#app')
if (!root) throw new Error('Missing app root')

root.innerHTML = `
  <div class="app-frame">
    <div class="gc-shell" data-testid="workspace-shell">
      <aside class="sidebar" data-testid="workspace-sidebar">
        <button class="guild-header" type="button">Тестовая гильдия</button>
        <button class="mobile-nav-close" aria-label="Закрыть навигацию">×</button>
        <div class="nav-drawer" data-testid="workspace-drawer">
          <div class="nav-content">
          <div class="channel-navigation">
            <section class="channel-category">
              <div class="channel-row" data-testid="channel-favorite-row">
                <button class="channel-button"><span class="channel-icon">#</span><span class="channel-name">favorite-test-channel</span></button>
                <button class="channel-favorite-toggle" aria-label="Добавить в избранное" aria-pressed="false">☆</button>
                <button class="channel-actions-button" aria-label="Действия с каналом favorite-test-channel">⋯</button>
              </div>
            </section>
          </div>
          <button aria-label="Открыть канал" class="channel-button selected">общее</button>
          <button class="channel-button" aria-label="Выбрать канал">Перейти в канал</button>
          </div>
        </div>
        <div class="mobile-voice-dock mobile-visible" data-testid="mobile-voice-dock">
          <span>Голос подключён</span>
          <button>Отключиться</button>
        </div>
        <footer class="user-footer">Егор · В сети</footer>
      </aside>
      <main class="main" data-testid="workspace-main" data-channel-id="general">
        <section class="text-conversation">
          <header class="main-header conversation-header">
            <button class="workspace-header-toggle workspace-header-toggle--nav" aria-label="Открыть навигацию">☰</button>
            <button aria-label="Открыть поиск">Поиск</button>
            <button aria-label="Открыть администрирование">Управление</button>
            <div class="main-title"><h2>общее</h2><small>Общение на любые темы</small></div>
          </header>
          <ol class="messages message-list" data-testid="message-list">
            <li class="message-item"><p>Состояние беседы сохраняется при изменении размера окна.</p></li>
          </ol>
          <div class="composer-wrap" data-testid="composer-wrap">
            <div class="composer"><textarea aria-label="Сообщение" placeholder="Написать сообщение"></textarea><button aria-label="Отправить">Отправить</button></div>
          </div>
        </section>
      </main>
      <aside class="members" data-testid="members-rail"><h2 class="members-heading">Участники</h2><p>Егор</p></aside>
      <aside id="search-aside-panel" class="members search-aside" data-testid="search-drawer" hidden><header class="search-panel-heading"><h1>Поиск сообщений</h1><button class="search-close" aria-label="Закрыть поиск">×</button></header><input aria-label="Поиск по беседе" /></aside>
      <aside data-testid="admin-panel" hidden><button aria-label="Закрыть администрирование">×</button><h1>Управление гильдией</h1></aside>
      <button class="drawer-scrim" aria-label="Закрыть навигацию и участников" aria-hidden="true" style="display: none"></button>
    </div>
  </div>
`

const sidebar = root.querySelector<HTMLElement>('[data-testid="workspace-sidebar"]')!
const scrim = root.querySelector<HTMLElement>('.drawer-scrim')!
const state = { navOpen: { value: false }, membersOpen: { value: false }, activePanel: { value: 'none' } }
function render(): void {
  root.dataset.drawerState = state.navOpen.value ? 'nav' : state.membersOpen.value ? 'members' : state.activePanel.value
  root.querySelector<HTMLElement>('.gc-shell')!.classList.toggle('search-active', state.activePanel.value === 'search')
  sidebar.classList.toggle('is-open', state.navOpen.value)
  scrim.style.display = state.navOpen.value || state.membersOpen.value || state.activePanel.value === 'search' ? '' : 'none'
  scrim.setAttribute('aria-hidden', String(scrim.style.display === 'none'))
  root.querySelector<HTMLElement>('[aria-label="Открыть поиск"]')!.setAttribute('aria-expanded', String(state.activePanel.value === 'search'))
  const searchDrawer = root.querySelector<HTMLElement>('[data-testid="search-drawer"]')!
  searchDrawer.hidden = state.activePanel.value !== 'search'
  searchDrawer.style.display = state.activePanel.value === 'search' ? 'block' : 'none'
  root.querySelector<HTMLElement>('[data-testid="admin-panel"]')!.hidden = state.activePanel.value !== 'admin'
}
function selectDrawer(drawer: WorkspaceHistoryView | null, navigate = false): void {
  state.navOpen.value = drawer === 'nav'
  state.membersOpen.value = drawer === 'members'
  state.activePanel.value = drawer === 'search' || drawer === 'admin' || drawer === 'audio' || drawer === 'profile' ? drawer : 'none'
  if (navigate) clearWorkspaceDrawerHistory(window.history)
  else syncWorkspaceDrawerHistory(window.history, drawer)
  render()
}
window.addEventListener('popstate', (event) => { restoreWorkspaceDrawerState(state, event.state); render() })
restoreWorkspaceDrawerState(state, window.history.state)
render()
root.querySelector('[aria-label="Открыть навигацию"]')?.addEventListener('click', () => {
  selectDrawer(state.navOpen.value ? null : 'nav')
})
root.querySelector('.mobile-nav-close')?.addEventListener('click', () => {
  selectDrawer(null)
})
root.querySelector('.drawer-scrim')?.addEventListener('click', () => selectDrawer(null))
root.querySelector('[aria-label="Открыть поиск"]')?.addEventListener('click', () => selectDrawer(state.activePanel.value === 'search' ? null : 'search'))
root.querySelector('[aria-label="Закрыть поиск"]')?.addEventListener('click', () => selectDrawer(null))
root.querySelector('[aria-label="Открыть администрирование"]')?.addEventListener('click', () => selectDrawer(state.activePanel.value === 'admin' ? null : 'admin'))
root.querySelector('[aria-label="Закрыть администрирование"]')?.addEventListener('click', () => selectDrawer(null))
root.querySelector('[aria-label="Выбрать канал"]')?.addEventListener('click', () => {
  selectDrawer(null, true)
  root.querySelector<HTMLElement>('[data-testid="workspace-main"]')!.setAttribute('data-channel-id', 'announcements')
})
