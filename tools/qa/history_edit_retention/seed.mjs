import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
const uuid4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
const fixtureID = value => `overlay(overlay(md5(${value}) placing '4' from 13 for 1) placing '8' from 17 for 1)::uuid`
export function validateMessageIdentifiers(rows) {
  assert.ok(rows.length > 0)
  for (const row of rows) { assert.match(row.id, uuid4); assert.match(row.client_message_id, uuid4) }
}
export function fixtureSQL(channel, count, ratio, foreign = null) {
  assert.match(channel, uuid)
  assert.ok([50, 500, 1000, 5000, 10000].includes(count))
  assert.ok([0, 50, 100].includes(ratio))
  if (foreign !== null) assert.match(foreign, uuid)
  const target = foreign ? `'${foreign}'::uuid` : fixtureID(`'${channel}:' || CASE WHEN n=1 THEN 2 ELSE 1 END`)
  return `INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at,reply_to_id)
    SELECT ${fixtureID(`'${channel}:'||n`)},'${channel}'::uuid,
      (SELECT id FROM users WHERE login='qa_admin'),${fixtureID(`'${channel}:client:'||n`)},
      'Synthetic history entry '||n,now()-interval '1 day'+n*interval '1 second',
      CASE WHEN ${ratio}=100 OR (${ratio}=50 AND n%2=0) THEN ${target} ELSE NULL END
    FROM generate_series(1,${count}) n;`
}
export function seedHistory(owner, channel, count, ratio, foreign = null) {
  assert.match(owner ?? '', /^qa-client-[0-9a-f]{16}$/)
  const sql = fixtureSQL(channel, count, ratio, foreign)
  const label = execFileSync('docker', ['inspect', owner+'-db', '--format',
    '{{index .Config.Labels "boohtacord.qa.owner"}}'], { encoding: 'utf8' }).trim()
  assert.equal(label, owner, 'Refusing a foreign database')
  execFileSync('docker', ['exec', '-i', owner+'-db', 'psql', '-U', 'qa', '-d', 'qa',
    '-v', 'ON_ERROR_STOP=1'], { input: sql, stdio: ['pipe', 'pipe', 'pipe'] })
}
