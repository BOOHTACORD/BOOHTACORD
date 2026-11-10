import assert from'node:assert/strict'
import{execFileSync}from'node:child_process'
export function owned(owner,role,...command){assert.match(owner,/^qa272-[a-f0-9]{16}$/);assert.ok(['db','sfu'].includes(role));const name=owner+'-'+role;assert.equal(execFileSync('docker',['inspect',name,'--format','{{index .Config.Labels "boohtacord.qa.owner"}}'],{encoding:'utf8'}).trim(),owner);return execFileSync('docker',command.map(v=>v==='$owned'?name:v),{stdio:['ignore','pipe','pipe'],timeout:30000})}
