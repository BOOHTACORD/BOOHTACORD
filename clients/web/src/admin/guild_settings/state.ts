import { computed, ref } from 'vue'
import { validGuildName } from '../../guild/profile/client'
import { guildProfile } from '../../guild/profile/state'
import { GuildSettingsError, readGuildSettings, writeGuildSettings, type GuildSettings } from './client'
export function createGuildSettingsState(read = readGuildSettings, write = writeGuildSettings) {
  const name = ref(''), welcome = ref<string | null>(null), afkChannel = ref<string | null>(null), afkTimeout = ref(0), revision = ref(0), busy = ref(false), error = ref<string | null>(null), saved = ref(false)
  const baseline = ref<GuildSettings | null>(null)
  const dirty = computed(() => !!baseline.value && (name.value !== baseline.value.name || welcome.value !== baseline.value.welcomeChannelId || afkChannel.value !== (baseline.value.afkChannelId ?? null) || afkTimeout.value !== (baseline.value.afkTimeoutSeconds ?? 0)))
  function cancel(): void {
    if (busy.value || !baseline.value) return
    name.value = baseline.value.name; welcome.value = baseline.value.welcomeChannelId; afkChannel.value = baseline.value.afkChannelId ?? null; afkTimeout.value = baseline.value.afkTimeoutSeconds ?? 0; saved.value = false; error.value = null
  }
  function changeAfkChannel(channelID: string | null): void {
    afkChannel.value = channelID
    if (channelID === null) afkTimeout.value = 0
    else if (afkTimeout.value === 0) afkTimeout.value = 300
    saved.value = false
    error.value = null
  }
  let active = true
  async function load(): Promise<void> {
    busy.value = true; error.value = null
    try { const row = await read(); if (active) { name.value = row.name; welcome.value = row.welcomeChannelId; afkChannel.value = row.afkChannelId ?? null; afkTimeout.value = row.afkTimeoutSeconds ?? 0; revision.value = row.revision; baseline.value = row; saved.value = false } }
    catch (cause) { if (active) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить настройки.' }
    finally { if (active) busy.value = false }
  }
  async function save(availableChannels: string[], availableVoiceChannels: string[] = []): Promise<void> {
    if (!active || busy.value || !revision.value) return
    saved.value = false; error.value = null
    if (!validGuildName(name.value.trim())) { error.value = 'Название: от 1 до 80 символов, без переводов строк.'; return }
    if (welcome.value !== null && !availableChannels.includes(welcome.value)) { error.value = 'Выберите доступный текстовый канал или выключите приветствия.'; return }
    if ((afkChannel.value === null) !== (afkTimeout.value === 0) || (afkChannel.value !== null && (!availableVoiceChannels.includes(afkChannel.value) || afkTimeout.value < 60 || afkTimeout.value > 86400))) { error.value = 'Выберите доступный голосовой AFK-канал и интервал от 1 минуты до 24 часов.'; return }
    busy.value = true
    try {
      const row = await write({ name: name.value.trim(), expected_revision: revision.value, welcome_channel_id: welcome.value, afk_channel_id: afkChannel.value, afk_timeout_seconds: afkTimeout.value })
      if (active) { name.value = row.name; revision.value = row.revision; welcome.value = row.welcomeChannelId; afkChannel.value = row.afkChannelId ?? null; afkTimeout.value = row.afkTimeoutSeconds ?? 0; baseline.value = row; saved.value = true; void guildProfile.refresh(row.revision) }
    } catch (cause) {
      if (!active) return
      error.value = cause instanceof Error ? cause.message : 'Не удалось сохранить настройки.'
      if (cause instanceof GuildSettingsError && cause.status === 409) {
        try { const row = await read(); if (active) { revision.value = row.revision; baseline.value = row } }
        catch { if (active) { revision.value = 0; error.value += ' Перечитайте настройки перед повторной попыткой.' } }
      }
    } finally { if (active) busy.value = false }
  }
  return { name, welcome, afkChannel, afkTimeout, revision, busy, error, saved, dirty, changeAfkChannel, cancel, load, save, dispose: () => { active = false } }
}
