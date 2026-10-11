import { defineStore } from 'pinia'
import { ref } from 'vue'

import { loadTopology, type ChannelTopology, type TopologyRequest } from './topology_client'

export const useTopologyStore = defineStore('channel-topology', () => {
  const topology = ref<ChannelTopology | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  let inFlight: Promise<void> | null = null
  let pending = false
  let nextRequest: TopologyRequest | undefined

  async function drain(): Promise<void> {
    loading.value = true
    try {
      do {
        pending = false
        error.value = null
        const request = nextRequest
        try {
          topology.value = await loadTopology(request)
        } catch (cause) {
          error.value = cause instanceof Error ? cause.message : 'Не удалось получить каналы.'
        }
      } while (pending)
    } finally {
      loading.value = false
      inFlight = null
    }
  }

  function refresh(request?: TopologyRequest): Promise<void> {
    nextRequest = request
    if (inFlight) {
      // A hint received during a GET needs one fresh tail read, shared by all callers.
      pending = true
      return inFlight
    }
    inFlight = drain()
    return inFlight
  }

  return { topology, loading, error, refresh }
})
