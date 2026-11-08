export class SoundBurstLimit {
  private played: number[] = []
  allow(now: number): boolean {
    this.played = this.played.filter(time => time > now - 5000)
    if (this.played.length >= 3) return false
    this.played.push(now)
    return true
  }
  clear(): void { this.played = [] }
}
