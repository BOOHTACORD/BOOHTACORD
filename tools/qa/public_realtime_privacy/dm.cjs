function delivered(sockets, before) {
  return sockets.reduce((sum, socket) => sum + socket.dm, 0) > before
}

async function exercise(sender, observer, until) {
  const before = observer.sockets.reduce((sum, socket) => sum + socket.dm, 0)
  const page = sender.page
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  const navigation = page.getByRole('navigation', { name: 'Личные сообщения' })
  await navigation.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  await page.getByRole('dialog', { name: 'Новый личный диалог' }).getByRole('button', { name: 'qa_admin', exact: true }).click()
  await page.getByRole('textbox', { name: 'Сообщение', exact: true }).fill('Synthetic privacy fixture')
  const response = page.waitForResponse(value => value.request().method() === 'POST' &&
    new URL(value.url()).pathname.includes('/direct-messages/') && new URL(value.url()).pathname.endsWith('/messages'))
  await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  if ((await response).status() !== 201) throw Error('synthetic direct message was not accepted')
  await until(() => delivered(observer.sockets, before), 'authorized direct-message hint missing')
}

module.exports = { delivered, exercise }
