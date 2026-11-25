import { deflateSync } from 'node:zlib'

function chunk(name: string, data: Buffer): Buffer {
  const type = Buffer.from(name), body = Buffer.concat([type, data])
  let crc = 0xffffffff
  for (const byte of body) {
    crc ^= byte
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0)
  }
  const size = Buffer.alloc(4), checksum = Buffer.alloc(4)
  size.writeUInt32BE(data.length); checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0)
  return Buffer.concat([size, body, checksum])
}
export function qaImage(width = 256, height = 160): Buffer {
  const header = Buffer.alloc(13), rows = []
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 2
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(1 + width * 3)
    for (let x = 0; x < width; x++) {
      row[1+x*3] = x < width/2 ? 240 : 32
      row[2+x*3] = y < height/2 ? 120 : 220
      row[3+x*3] = x < width/2 ? 48 : 240
    }
    rows.push(row)
  }
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header),
    chunk('IDAT', deflateSync(Buffer.concat(rows))), chunk('IEND', Buffer.alloc(0))])
}
