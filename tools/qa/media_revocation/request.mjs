// Real same-origin secure-cookie transport. Expected actor is explicit for session mutations.
export async function api(page,path,method='GET',body,headers={}) {
  return page.evaluate(async({path,method,body,headers})=>{
    const response=await fetch('/api/v1'+path,{method,credentials:'same-origin',
      headers:{'Content-Type':'application/json',...headers},
      ...(body===undefined?{}:{body:JSON.stringify(body)})})
    return {status:response.status,body:response.status===204?null:await response.json(),retry_after:response.headers.get('Retry-After')}
  },{path,method,body,headers})
}

export async function priorSessionStatus(page,origin,cookie) {
  const response=await page.context().request.get(origin+'/api/v1/me/sessions',{headers:{Cookie:cookie}})
  return response.status()
}

export async function loginAccount(page,login,password,sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms)),onWait=()=>{}) {
  let response=await api(page,'/auth/login','POST',{login,password})
  if(response.status!==429)return response
  const header=response.retry_after
  if(typeof header!=='string'||!/^\d+$/.test(header)||Number(header)<1||Number(header)>300)throw new Error('Unbounded or missing Retry-After')
  onWait(Number(header))
  await sleep(Number(header)*1000+100)
  response=await api(page,'/auth/login','POST',{login,password})
  return response
}
