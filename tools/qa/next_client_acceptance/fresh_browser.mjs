// Independent publication cases must not inherit an earlier network reset.
export async function freshBrowser(owned, create) {
  const cookies = await owned.context.cookies()
  await owned.close()
  const replacement = await create()
  try {
    await replacement.context.addCookies(cookies)
    return replacement
  } catch (error) {
    await replacement.close()
    throw error
  }
}
