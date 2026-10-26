import type { Span } from '@opentelemetry/api'
import { activeAction } from './scope'
import { telemetrySession, type SessionSnapshot } from './session'
export function actionHeaders(span:Span,headers:Headers):void {
 const action=activeAction()
 if(!action || !telemetrySession.current(action.snapshot) || !action.snapshot.binding)return
 span.setAttributes(action.attributes('checkpoint','unknown'))
 headers.set('X-Telemetry-Session',action.snapshot.binding)
 headers.set('X-App-Visit',action.snapshot.visit);headers.set('X-App-Flow',action.id)
 headers.set('X-App-Flow-Name',action.name);headers.set('X-App-Attempt',String(action.attempt))
 if(action.snapshot.media)headers.set('X-App-Media-Session',action.snapshot.media)
}
export function acceptSessionResponse(response:Response,snapshot:SessionSnapshot):void {
 if(!telemetrySession.current(snapshot))return
 if(response.status===401)telemetrySession.reset()
 else if(response.ok){telemetrySession.bindInstallation(response.headers.get('X-Installation-ID'));telemetrySession.bind(response.headers.get('X-Telemetry-Session'),response.headers.get('X-Telemetry-Schema'))}
}

