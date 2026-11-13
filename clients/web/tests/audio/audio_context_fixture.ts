export async function resumeAudio(context: AudioContext): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    await Promise.race([context.resume(), new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error('AudioContext resume timed out')), 8000)
    })])
  } catch (error) { void context.close(); throw error }
  finally { if (timer !== undefined) clearTimeout(timer) }
}
