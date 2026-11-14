export const voiceDeafenAttributeKey = 'boohtacord.voice.deafened.v1'

export function remoteParticipantDeafened(attributes?: Readonly<Record<string, string>>): boolean {
  return attributes?.[voiceDeafenAttributeKey] === 'true'
}
