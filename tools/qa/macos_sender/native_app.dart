import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/desktop_window_options.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/client_telemetry.dart';
import 'package:boohtacord_desktop/src/services/third_party_audio_licenses.dart';
import 'package:boohtacord_desktop/src/telemetry/traced_app_state.dart';
import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'qa98325_namespace_storage.dart';
import 'qa98325_http_observer.dart';

class QaTls extends HttpOverrides {
 QaTls(this.pin); final String pin;
 @override HttpClient createHttpClient(SecurityContext? c)=>super.createHttpClient(c)..badCertificateCallback=(cert,host,port)=>host=='localhost'&&port==5060&&sha256.convert(cert.der).toString()==pin;
}
Future<void> main() async {
 final clock=Stopwatch()..start();
 WidgetsFlutterBinding.ensureInitialized();
 const origin=String.fromEnvironment('QA_API_BASE'),pin=String.fromEnvironment('QA_CERT_SHA256'),password=String.fromEnvironment('QA_PASSWORD'),namespace=String.fromEnvironment('QA_STORAGE_NAMESPACE');
 final mode=Platform.environment['BOOHTACORD_QA_MODE']??'startup';
 final index=int.parse(Platform.environment['BOOHTACORD_QA_INDEX']??'0');
 if(!Platform.isMacOS||origin!='https://localhost:5060/api/v1'||pin.length!=64||password.isEmpty||index<0||index>20)throw StateError('Owned physical Mac QA configuration required');
 HttpOverrides.global=QaTls(pin);
 final rows=<Map<String,Object?>>[];
 SharedPreferences? prefs;Future<void> writes=Future.value();
 var phase='entry',done=false;
 void observe(Map<String,Object?> row){
  rows.add({'at_ms':clock.elapsedMicroseconds/1000,...row});
  if(prefs!=null){final value=jsonEncode({'status':done?'DONE':'RUNNING','mode':mode,'index':index,'phase':phase,'events':rows});writes=writes.then((_) async {await prefs!.setString('qa98325_state',value);});}
 }
 observe({'event':'dart_entry'});
 final originalDebugPrint=debugPrint;
 debugPrint=(String? text,{int? wrapWidth}){
  if(text!=null&&text.startsWith('[screen-share] ')){
   final values=<String,Object?>{'event':'screen_diagnostic'};
   for(final part in text.split(' ').skip(1)){final pair=part.split('=');if(pair.length==2&&const{'event','duration_ms','error_class','http_status_class','sender_stats_entries','frames_sent','bytes_sent','encoded_fps','local_screen_publications'}.contains(pair[0]))values['diagnostic_'+pair[0]]=num.tryParse(pair[1])??pair[1];}
   observe(values);
  }
  originalDebugPrint(text,wrapWidth:wrapWidth);
 };
 final storage=QaNamespaceStorage(FlutterSecureStoragePlatform.instance,namespace,(kind,duration)=>observe({'event':'keychain_operation','operation':kind,'duration_ms':duration}));
 FlutterSecureStoragePlatform.instance=storage;
 prefs=await SharedPreferences.getInstance();
 await prefs!.setString('server_url',origin);
 observe({'event':'preferences_ready'});
 if(mode=='cleanup'){
  await storage.delete(key:'boohtacord_session_cookie:https://localhost:5060',options:{'usesDataProtectionKeychain':'false'});
  await storage.delete(key:'boohtacord_session_cookie',options:{'usesDataProtectionKeychain':'false'});
  done=true;phase='cleanup_complete';observe({'event':'owned_keychain_keys_deleted'});await writes;exit(0);
 }
 registerThirdPartyAudioLicenses();
 await windowManager.ensureInitialized();
 await windowManager.waitUntilReadyToShow(desktopWindowOptions,() async {await windowManager.setTitle('BOOHTACORD QA98325');await windowManager.show();await windowManager.focus();});
 observe({'event':'window_ready'});
 final transport=QaHttpObserver(http.Client(),observe,()=>clock.elapsedMicroseconds/1000);
 final api=ApiClient(client:transport);
 ClientTelemetry.session=api.transport.session.telemetry;
 await ClientTelemetry.initialize(api.submitClientSpans);
 final state=TracedAppState(api,audioDeviceBootstrap:() async {await LiveKitClient.initialize();await rtc.ensurePeerConnectionFactoryReady();});
 final updates=UpdateController(api:UpdateApi(baseUrl:()=>api.baseUrl),identity:await NativeUpdateIdentity.load());
 Map<String,Object?>? previous;DateTime? sampledAt;
 void inspect(){
  final next=<String,Object?>{'event':'state','phase':state.phase.name,'voice_phase':state.voicePhase.name,'screen_phase':state.screenSharePhase.name,'sample_present':state.screenShareSenderSampledAt!=null};
  if(jsonEncode(next)!=jsonEncode(previous)){previous=next;observe(next);}
  if(state.screenShareSenderSampledAt!=sampledAt&&state.screenShareSenderSampledAt!=null){sampledAt=state.screenShareSenderSampledAt;observe({'event':'sample_updated','collection_state':state.screen.metrics.reportMeasurementFields['collection_state'],'stats_source':state.screen.metrics.reportMeasurementFields['stats_source'],'report_state':state.screenShareSenderReport?.state});}
 }
 state.addListener(inspect);
 WidgetsBinding.instance.addPostFrameCallback((_){observe({'event':'first_flutter_frame'});});
 runApp(Directionality(textDirection:TextDirection.ltr,child:Stack(children:[BoohtacordApp(state:state,updates:updates),const Positioned(right:12,bottom:12,child:QaPattern())])));
 Future<void> delay(int seconds)=>Future<void>.delayed(Duration(seconds:seconds));
 Future<void> control(String action) async {
  phase=action;observe({'event':'control_requested','action':action});
  for(var n=0;n<200;n++){await prefs!.reload();if(prefs!.getString('qa98325_control')=='$index:continue')return;await Future<void>.delayed(const Duration(milliseconds:250));}
  throw StateError('Owned control deadline exceeded');
 }
 try {
  phase='initializing';observe({'event':'initialize_start'});await state.initialize();inspect();
  final restored=state.phase==AppPhase.ready;
  observe({'event':'initialize_finished','restored_session':restored,'phase':state.phase.name});
  if(state.phase==AppPhase.connectionError)throw StateError('Production startup did not complete');
  if(!restored){await state.authenticate('qa_admin',password,register:false);observe({'event':'owned_auth_finished','phase':state.phase.name});}
  final voice=state.topology!.categories.expand((c)=>c.channels).firstWhere((c)=>c.name=='QaVoice');
  await state.selectChannel(voice);observe({'event':'prejoin_ready','roster_present':state.voiceRosters!=null});updates.start();
  if(mode=='startup'){phase='startup_ready';done=true;observe({'event':'startup_complete'});await writes;return;}
  await state.joinVoice(voice,listenerOnly:true);observe({'event':'native_sfu_connected','remote_participants':state.room?.remoteParticipants.length});
  await delay(2);
  await windowManager.setTitle('BOOHTACORD QA98325');await Future<void>.delayed(const Duration(milliseconds:250));
  final sources=await rtc.desktopCapturer.getSources(types:[rtc.SourceType.Window],thumbnailSize:rtc.ThumbnailSize(1,1));
  final own=sources.where((s)=>s.name.contains('QA98325')).toList();
  observe({'event':'own_window_source','count':own.length});
  if(own.length!=1)throw StateError('Own synthetic window capture source unavailable');
  if(mode=='stall')await control('pause_api');
  phase='publish';await state.startScreenShare(sourceId:own.single.id,captureScreenAudio:false);
  observe({'event':'publish_returned','screen_phase':state.screenSharePhase.name});
  if(state.screenSharePhase!=ScreenSharePhase.sharing)throw StateError('Actual native publication unavailable');
  if(mode=='failure'){await delay(6);await control('stop_api');}
  final requested=int.tryParse(Platform.environment['BOOHTACORD_QA_PUBLISH_SECONDS']??'');
  final duration=requested!=null&&requested>=10&&requested<=120?requested:mode=='stall'?32:mode=='failure'?18:16;
  await delay(duration);
  if(mode=='restart'){
   await state.stopScreenShare();observe({'event':'rapid_stop'});await state.startScreenShare(sourceId:own.single.id,captureScreenAudio:false);observe({'event':'republish_returned','screen_phase':state.screenSharePhase.name});await delay(10);
  }
  await state.stopScreenShare();observe({'event':'publication_stopped','maximum_pending_reports':transport.maximumPendingReports,'pending_reports':transport.pendingReports});
  final reportCount=rows.where((r)=>r['event']=='http_start').length;
  await delay(2);observe({'event':'post_stop_idle','new_reports':rows.where((r)=>r['event']=='http_start').length-reportCount});
  await state.leaveVoice();phase='sender_complete';done=true;observe({'event':'sender_complete'});await writes;
 }catch(error){phase='failed';done=true;observe({'event':'failed','error_type':error.runtimeType.toString()});await writes;}
}
class QaPattern extends StatefulWidget {const QaPattern({super.key});@override State<QaPattern> createState()=>_QaPatternState();}
class _QaPatternState extends State<QaPattern>{int tick=0;Timer? timer;@override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:100),(_){if(mounted)setState(()=>tick++);});}@override void dispose(){timer?.cancel();super.dispose();}@override Widget build(BuildContext context)=>ColoredBox(color:tick.isEven?Colors.deepPurple:Colors.teal,child:SizedBox(width:120,height:64,child:Center(child:Text('QA $tick',style:const TextStyle(color:Colors.white,fontSize:24)))));}
