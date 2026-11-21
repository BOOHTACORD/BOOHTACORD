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

  async function drain(owner: number): Promise<void> {
    loading.value = true
    try {
      do {
        pending = false
        error.value = null
        const request = nextRequest
        try {
          const next = await loadTopology(request)
          if (owner !== epoch || !admission()) return
          topology.value = next
        } catch (cause) {
          if (owner === epoch && admission()) error.value = requestFailureMessage(cause, 'Не удалось получить каналы.')
        }
      } while (pending && owner === epoch && admission())
    } finally {
      if (owner === epoch) { loading.value = false; inFlight = null }
    }
  }

  function refreshOwned(request: TopologyRequest | undefined, current: () => boolean): Promise<void> {
    if (!current()) return Promise.resolve()
    nextRequest = request
    if (inFlight && admission()) {
      // A hint received during a GET needs one fresh tail read, shared by all callers.
      pending = true
      // Bind UI work to the live socket; ordinary reads cannot remove that fence.
      if (current !== ui) admission = current
      return inFlight
    }
    admission = current
    inFlight = drain(++epoch)
    return inFlight
  }

  const refresh = (request?: TopologyRequest) => refreshOwned(request, ui)
  const refreshRealtime = (current: () => boolean) => refreshOwned(undefined, current)
  return { topology, loading, error, refresh, refreshRealtime }
})
