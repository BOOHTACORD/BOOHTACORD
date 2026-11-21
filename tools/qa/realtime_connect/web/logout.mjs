import https from 'node:https'

// Revoke only this disposable session on the actual API, outside browser storage.
export async function revokeSession(page) {
  const cookies=(await page.context().cookies()).filter(c=>c.httpOnly)
  if(cookies.length!==1) throw Error('One owned session required')
  await new Promise((resolve,reject)=>{
    const request=https.request({hostname:'localhost',port:4910,path:'/api/v1/auth/logout',
      method:'POST',rejectUnauthorized:false,headers:{origin:'https://localhost:4910',
        cookie:cookies.map(c=>c.name+'='+c.value).join('; ')}},response=>{
      response.resume()
      if(response.statusCode!==204) reject(Error('Owned server logout failed'))
      else response.on('end',resolve)
    })
    request.on('error',()=>reject(Error('Owned server logout transport failed')))
    request.setTimeout(5000,()=>request.destroy())
    request.end()
  })
}
