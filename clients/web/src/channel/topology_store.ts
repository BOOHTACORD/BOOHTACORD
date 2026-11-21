import { defineStore } from 'pinia'
import { ref } from 'vue'

import { requestFailureMessage } from '../request_feedback'
import { loadTopology, type ChannelTopology, type TopologyRequest } from './topology_client'

export const useTopologyStore = defineStore('channel-topology', () => {
  const topology = ref<ChannelTopology | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  let inFlight: Promise<void> | null = null
  let pending = false
  let nextRequest: TopologyRequest | undefined
  const ui = () => true
  let admission = ui, epoch = 0

  async function drain(owner: number, current: () => boolean): Promise<void> {
    loading.value = true
    try {
      do {
        pending = false
        error.value = null
        const request = nextRequest
        try {
          const next = await loadTopology(request)
          if (owner !== epoch || !current()) return
          topology.value = next
        } catch (cause) {
          if (owner === epoch && current()) error.value = requestFailureMessage(cause, 'Не удалось получить каналы.')
        }
      } while (pending && owner === epoch && current())
    } finally {
      if (owner === epoch) { loading.value = false; inFlight = null }
    }
  }

  function refreshOwned(request: TopologyRequest | undefined, current: () => boolean): Promise<void> {
    if (!current()) return Promise.resolve()
    nextRequest = request
    if (inFlight && admission === current) {
      // A hint received during a GET needs one fresh tail read, shared by all callers.
      pending = true
      return inFlight
    }
    admission = current
    inFlight = drain(++epoch, current)
    return inFlight
  }

  const refresh = (request?: TopologyRequest) => refreshOwned(request, ui)
  const refreshRealtime = (current: () => boolean) => refreshOwned(undefined, current)
  return { topology, loading, error, refresh, refreshRealtime }
})
