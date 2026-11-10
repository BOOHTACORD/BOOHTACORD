export interface KeyboardEventLike {
  code: string
  preventDefault(): void
  target: { closest?(selector: string): unknown } | null
}

export interface KeyboardInput {
  addEventListener(type: 'keydown' | 'keyup' | 'blur' | 'visibilitychange', listener: (event: KeyboardEventLike) => void): void
  removeEventListener(type: 'keydown' | 'keyup' | 'blur' | 'visibilitychange', listener: (event: KeyboardEventLike) => void): void
}

function interactiveTarget(target: KeyboardEventLike['target']): boolean {
  return Boolean(target?.closest?.('input, textarea, select, button, [role="button"], [contenteditable="true"], [role="dialog"]'))
}

export class PushToTalk {
  private pressed = false

  constructor(
    private readonly source: KeyboardInput,
    private readonly key: string,
    private readonly onChanged: (pressed: boolean) => void,
  ) {}

  start(): void {
    this.source.addEventListener('keydown', this.onKeyDown)
    this.source.addEventListener('keyup', this.onKeyUp)
    this.source.addEventListener('blur', this.release)
    this.source.addEventListener('visibilitychange', this.release)
  }

  stop(): void {
    this.source.removeEventListener('keydown', this.onKeyDown)
    this.source.removeEventListener('keyup', this.onKeyUp)
    this.source.removeEventListener('blur', this.release)
    this.source.removeEventListener('visibilitychange', this.release)
    this.release()
  }

  private readonly onKeyDown = (event: KeyboardEventLike): void => {
    if (event.code !== this.key || interactiveTarget(event.target)) return
    event.preventDefault()
    this.setPressed(true)
  }

  private readonly onKeyUp = (event: KeyboardEventLike): void => {
    if (event.code === this.key) this.setPressed(false)
  }

  private readonly release = (): void => this.setPressed(false)

  private setPressed(pressed: boolean): void {
    if (this.pressed === pressed) return
    this.pressed = pressed
    this.onChanged(pressed)
  }
}
