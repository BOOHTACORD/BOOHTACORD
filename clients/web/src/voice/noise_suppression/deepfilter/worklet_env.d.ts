export function setEntropy(bytes: Uint8Array): Uint8Array
export function releaseEntropy(bytes?: Uint8Array): void
export function withEntropy<T>(bytes: Uint8Array, callback: () => T): T
export function takeEntropy<T extends ArrayBufferView>(target: T): T
