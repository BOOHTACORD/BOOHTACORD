export async function runScenario(adapter, expected, stage = () => {}) {
  try {
    if (!/^[a-f0-9]{40}$/.test(expected)) throw Error('Invalid expected revision')
    stage('source_before')
    if (await adapter.revision() !== expected) throw Error('Installed revision differs')
    stage('login')
    await adapter.login()
    stage('room')
    await adapter.selectEmptyRoom()
    stage('connect')
    await adapter.connect()
    stage('publish')
    await adapter.publish()
    stage('disconnect')
    await adapter.disconnect()
    stage('logout')
    await adapter.logout()
    stage('source_after')
    if (await adapter.revision() !== expected) throw Error('Installed revision changed')
  } finally {
    await adapter.close()
  }
}
