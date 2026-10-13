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
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/content_mode.dart';
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
import 'qa98325_stage_scene.dart';
import 'qa98325_capture_observer.dart';
import 'qa98325_descriptor_observer.dart';
import 'qa98325_source_policy.dart';
import 'qa98325_lifecycle_acceptance.dart';
import 'qa98325_receiver_observer.dart';

class QaTls extends HttpOverrides {
 QaTls(this.pin,this.ca); final String pin,ca;
 @override HttpClient createHttpClient(SecurityContext? c){
  if(ca.isNotEmpty){final context=SecurityContext(withTrustedRoots:false)..setTrustedCertificatesBytes(base64Decode(ca));return super.createHttpClient(context);}
  return super.createHttpClient(c)..badCertificateCallback=(cert,host,port)=>host=='localhost'&&port==5060&&sha256.convert(cert.der).toString()==pin;
 }
}
Future<void> main() async {
 final clock=Stopwatch()..start();
 WidgetsFlutterBinding.ensureInitialized();
 const origin=String.fromEnvironment('QA_API_BASE'),pin=String.fromEnvironment('QA_CERT_SHA256'),password=String.fromEnvironment('QA_PASSWORD'),namespace=String.fromEnvironment('QA_STORAGE_NAMESPACE');
 final mode=Platform.environment['BOOHTACORD_QA_MODE']??'startup';
 final index=int.parse(Platform.environment['BOOHTACORD_QA_INDEX']??'0');
 if(!Platform.isMacOS||origin!='https://localhost:5060/api/v1'||pin.length!=64||password.isEmpty||index<0||index>20)throw StateError('Owned physical Mac QA configuration required');
 HttpOverrides.global=QaTls(pin,const String.fromEnvironment('QA_TRUSTED_CA_B64'));
 final stageMode=Platform.environment['BOOHTACORD_QA_STAGE']=='1';
 final stageStatic=Platform.environment['BOOHTACORD_QA_STATIC']=='1';
 final displayCapture=Platform.environment['BOOHTACORD_QA_DISPLAY']=='1';
 final captureCounters=Platform.environment['BOOHTACORD_QA_CAPTURE_COUNTERS']=='1';
 final stageResolution=int.tryParse(Platform.environment['BOOHTACORD_QA_RESOLUTION']??'')??1080;
 final stageRate=int.tryParse(Platform.environment['BOOHTACORD_QA_FPS']??'')??60;
 if(stageMode&&(![720,1080].contains(stageResolution)||![30,60].contains(stageRate)))throw StateError('Bounded QA stage profile required');
 final stageContentMode=qaContentMode(Platform.environment['QA_NATIVE_MODE']);
 final duration=qaPublishDuration(Platform.environment['BOOHTACORD_QA_PUBLISH_SECONDS'],fallback:mode=='stall'?32:mode=='failure'?18:16);
 final stageLedger=StageFrameLedger();
 final rows=<Map<String,Object?>>[];
 SharedPreferences? prefs;Future<void> writes=Future.value();
 T? optional<T>(T Function() read){try{return read();}on NoSuchMethodError{return null;}}
 var phase='entry',done=false;Timer? captureTimer;var captureBusy=false;var captureGeneration=0;
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
 await prefs.setString('server_url',origin);
 observe({'event':'preferences_ready'});
 if(mode=='cleanup'){
  await storage.delete(key:'boohtacord_session_cookie:https://localhost:5060',options:{'usesDataProtectionKeychain':'false'});
  await storage.delete(key:'boohtacord_session_cookie',options:{'usesDataProtectionKeychain':'false'});
  done=true;phase='cleanup_complete';observe({'event':'owned_keychain_keys_deleted'});await writes;exit(0);
 }
 registerThirdPartyAudioLicenses();
 await windowManager.ensureInitialized();
 await windowManager.waitUntilReadyToShow(desktopWindowOptions,() async {await windowManager.setTitle('BOOHTACORD QA98325');await windowManager.show();await windowManager.focus();});
 if(stageMode)await windowManager.setSize(const Size(1280,720));
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
  if(state.screenShareSenderSampledAt!=sampledAt&&state.screenShareSenderSampledAt!=null){sampledAt=state.screenShareSenderSampledAt;if(stageMode){observe({'event':'source_scene_observation',...stageLedger.snapshot()});observe({'event':'sender_stage_sample','monotonic_sample_ms':state.screen.metrics.sampledAtMonotonicMs,'layers':[for(final layer in state.screen.metrics.layerDiagnostics){'layer_index':state.screen.metrics.layerDiagnostics.indexOf(layer),'frame_counter_source':layer.frameCounterSource,'codec':layer.codec,'state':layer.state,'width':layer.width,'height':layer.height,'stats_timestamp_ms':layer.timestampMs,'interval_ms':layer.windowMs,'encoded_fps':optional<num?>(()=>(layer as dynamic).encodedFramesPerSecond),'sent_fps':optional<num?>(()=>(layer as dynamic).sentFramesPerSecond),'encoder_implementation_reported':optional<String?>(()=>(layer as dynamic).encoderImplementation),'power_efficient_encoder_reported_not_hardware':optional<bool?>(()=>(layer as dynamic).powerEfficientEncoder),'average_qp_codec_dependent':optional<num?>(()=>(layer as dynamic).averageQp),'publisher_selected_transport':optional<Map<String,Object?>?>(()=>(layer as dynamic).transport?.toPublicJson()),'bitrate_bps':layer.bitrateBps,'encode_ms_per_frame':layer.encodeMsPerFrame,'quality_limitation':layer.qualityLimitationReason,'nack_per_second':layer.nackPerSecond,'pli_per_second':layer.pliPerSecond}]});}
   if(stageMode){
    final dynamic runtime=optional<dynamic>(()=>(state.screen as dynamic).descriptor.runtime);
    if(runtime!=null){
     final raw=runtime.lastDescriptor as Map?;
     observe({'event':'descriptor_state','writer_status':publicDescriptorStatus(runtime.status),'fresh_confirmation_present':runtime.confirmedAt!=null,'applied_ack_present':runtime.appliedAt!=null,'confirmation_wall_time':runtime.confirmedAt?.toUtc().toIso8601String(),'ack_wall_time':runtime.appliedAt?.toUtc().toIso8601String(),...publicDescriptorFields(raw)});
     final attr=state.room?.localParticipant?.attributes['boohtacord.screen-share.v1'];
     if(attr!=null&&utf8.encode(attr).length<=4096){try{final decoded=jsonDecode(attr);final scope=decoded is Map?decoded['scope']:null;final matches=scope is Map&&scope['origin_id']==api.transport.publicHeaders()['origin']&&scope['account_id']==state.user?.accountId&&scope['room_id']==state.room?.name;observe({'event':'server_descriptor_attribute','scope_matches_independent_session':matches,...publicDescriptorFields(matches&&decoded is Map?decoded:null)});}on FormatException{observe({'event':'server_descriptor_attribute','status':'invalid_json'});}}
    }
   }
   observe({'event':'sample_updated','collection_state':state.screen.metrics.reportMeasurementFields['collection_state'],'stats_source':state.screen.metrics.reportMeasurementFields['stats_source'],'report_state':state.screenShareSenderReport?.state});}
 }
 state.addListener(inspect);
 WidgetsBinding.instance.addPostFrameCallback((_){observe({'event':'first_flutter_frame'});});
 runApp(Directionality(textDirection:TextDirection.ltr,child:Stack(children:[BoohtacordApp(state:state,updates:updates),if(stageMode)Positioned.fill(child:SyntheticStageScene(ledger:stageLedger,staticScene:stageStatic,profileResolution:stageResolution)),if(!stageMode)const Positioned(right:12,bottom:12,child:QaPattern())])));
 Future<void> delay(int seconds)=>Future<void>.delayed(Duration(seconds:seconds));
 Future<void> control(String action) async {
  phase=action;observe({'event':'control_requested','action':action});
  for(var n=0;n<qaControlPollCount(action);n++){await prefs!.reload();if(prefs!.getString('qa98325_control')=='$index:continue')return;await Future<void>.delayed(const Duration(milliseconds:250));}
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
  if(stageMode){try{final caps=await rtc.getRtpSenderCapabilities('video').timeout(const Duration(seconds:2));observe({'event':'native_codec_capabilities','codecs':[for(final codec in caps.codecs??[]) {'mimeType':codec.mimeType,'clockRate':codec.clockRate,'fmtp':codec.sdpFmtpLine?.split(';').map((p)=>p.trim()).where((p)=>RegExp(r'^(profile-level-id|packetization-mode|level-asymmetry-allowed)=[0-9a-f]{1,6}$',caseSensitive:false).hasMatch(p)).toList()??[]}]});}catch(_){observe({'event':'native_codec_capabilities','status':'unavailable'});}}
  await state.joinVoice(voice,listenerOnly:true);observe({'event':'native_sfu_connected','remote_participants':state.room?.remoteParticipants.length});
  if(Platform.environment['QA_NATIVE_RECEIVER']=='1'){
   phase='receiver_observation';final deadline=DateTime.now().add(const Duration(seconds:85));final modes=<String>{};String? selected,lastDigest;
   while(DateTime.now().isBefore(deadline)){
    final participants=state.room?.remoteParticipants.values.toList()??<RemoteParticipant>[];
    final candidates=participants.where((p)=>qaObserveReceiverParticipant(p,expectedOrigin:api.transport.publicHeaders()['origin'],expectedRoomId:state.room?.name)['remote_publication_present']==true).toList();
    if(candidates.length==1){
     final participant=candidates.single;
     if(selected!=participant.identity){await state.selectRemoteScreenForViewing(participant.identity);selected=participant.identity;}
     final row=qaObserveReceiverParticipant(participant,expectedOrigin:api.transport.publicHeaders()['origin'],expectedRoomId:state.room?.name);
     final digest=jsonEncode(row);
     if(digest!=lastDigest){observe(row);lastDigest=digest;}
     if(row['descriptor_valid']==true&&row['scope_verified']==true&&row['remote_track_present']==true&&row['remote_subscribed']==true&&const{'motion','text'}.contains(row['mode']))modes.add(row['mode']as String);
     if(modes.containsAll(['motion','text']))break;
    }
    await delay(1);
   }
   if(!modes.containsAll(['motion','text']))throw StateError('Actual current receiver modes were not observed');
   observe({'event':'receiver_two_modes_confirmed','modes':['motion','text'],'source':'actual_SFU_attributes_production_scoped_parser','sender_metrics_proven':false});
   await control('review_receiver');await state.selectRemoteScreenForViewing(null);await state.leaveVoice();phase='receiver_complete';done=true;observe({'event':'receiver_complete'});await writes;return;
  }
  await delay(2);
  await windowManager.setTitle('BOOHTACORD QA98325');await Future<void>.delayed(const Duration(milliseconds:250));
  if(displayCapture){
   if(!stageMode)throw StateError('Display requires own synthetic stage');
   await windowManager.setFullScreen(true);await delay(2);
   await control('verify_fullscreen_display');
  }
  final sources=await rtc.desktopCapturer.getSources(types:[displayCapture?rtc.SourceType.Screen:rtc.SourceType.Window],thumbnailSize:rtc.ThumbnailSize(1,1));
  final own=displayCapture?sources:sources.where((s)=>s.name.contains('QA98325')).toList();
  if(displayCapture&&!allowDisplayCapture(stage:stageMode,fullscreen:await windowManager.isFullScreen(),reviewed:true,displayCount:sources.length))throw StateError('Exact reviewed own fullscreen display unavailable');
  observe({'event':'own_window_source','count':own.length});
  if(own.length!=1)throw StateError('Own synthetic window capture source unavailable');
  if(mode=='stall')await control('pause_api');
  if(stageMode&&stageLedger.paintAttempts==0)throw StateError('Own synthetic scene was not painted');
  phase='publish';await state.startScreenShare(sourceId:own.single.id,captureScreenAudio:false,contentMode:stageContentMode=='text'?ScreenShareContentMode.text:ScreenShareContentMode.motion,quality:stageMode?ScreenShareQuality(resolution:stageResolution,frameRate:stageRate):null);
  observe({'event':'publish_returned','screen_phase':state.screenSharePhase.name});
  if(stageMode)observe({'event':'stage_profile','requested_resolution':stageResolution,'requested_fps':stageRate,'state_resolution':state.screen.quality.resolution,'state_fps':state.screen.quality.frameRate,'source_class':displayCapture?'reviewed_own_fullscreen_display':'owned_window','capture_engine':'unavailable-no-native-counter','static_scene':stageStatic,'native_capture_counters':null});
  if(state.screenSharePhase!=ScreenSharePhase.sharing)throw StateError('Actual native publication unavailable');
  if(stageMode&&captureCounters){
   final generation=++captureGeneration;
   captureTimer=Timer.periodic(const Duration(seconds:1),(_) async {
    if(captureBusy||generation!=captureGeneration)return;
    final track=state.screen.metrics.track;if(track==null)return;captureBusy=true;
    try{final raw=await rtc.WebRTC.invokeMethod('mediaStreamTrackGetCaptureSnapshot',{'trackId':track.mediaStreamTrack.id}).timeout(const Duration(seconds:1));if(generation==captureGeneration&&raw is Map)observe({'event':'native_capture_sample',...sanitizeCaptureSnapshot(raw)});}
    catch(_){if(generation==captureGeneration)observe({'event':'native_capture_sample','status':'unavailable','reason':'native_bridge_missing_or_timeout'});}
    finally{captureBusy=false;}
   });
  }
  if(stageMode){
   unawaited(Future<void>.delayed(const Duration(seconds:20),() async {
    if(state.screenSharePhase!=ScreenSharePhase.sharing)return;
    try{
     // One read before the steady interval; no new ongoing stats loop.
     final room=state.room,track=state.screen.metrics.track;
     if(room==null||track==null)return;
     // ignore: invalid_use_of_internal_member
     final senders=await room.engine.publisher?.pc.getSenders().timeout(const Duration(seconds:1));
     final matching=senders?.where((s)=>s.track?.id==track.mediaStreamTrack.id).toList();
     if(matching==null||matching.length!=1){observe({'event':'fresh_encoder_parameters','status':'unknown'});return;}
     final encodings=matching.single.parameters.encodings;
     observe({'event':'fresh_encoder_parameters','wall_time':DateTime.now().toUtc().toIso8601String(),'layers':[for(final e in encodings?.take(2)??<rtc.RTCRtpEncoding>[]) {'max_fps_present':e.maxFramerate!=null,'max_fps':e.maxFramerate,'max_bitrate_present':e.maxBitrate!=null,'max_bitrate_bps':e.maxBitrate,'scale_down_by_present':e.scaleResolutionDownBy!=null,'scale_down_by':e.scaleResolutionDownBy,'active':e.active}]});
    }catch(_){observe({'event':'fresh_encoder_parameters','status':'unavailable'});}
   }));
  }
  if(Platform.environment['QA_METADATA_ISOLATED_FAULT']=='1'){await delay(8);await control('enable_metadata_fault');state.updateScreenShareContentMode(ScreenShareContentMode.text);observe({'event':'isolated_metadata_fault_mode_change','mode':'text','profile':state.screenShareSelectedProfileId});}
  if(mode=='failure'){await delay(6);await control('stop_api');}
  await delay(duration);
  if(Platform.environment['QA_NATIVE_LIFECYCLE']=='1'){
   captureGeneration++;captureTimer?.cancel();final initialTrack=state.screen.metrics.track,initialLease=state.voice.leaseId;
   final result=await runQaLifecycleAcceptance(
    update:(resolution,fps)=>state.updateScreenShareQuality(ScreenShareQuality(resolution:resolution,frameRate:fps)),
    stop:state.stopScreenShare,
    start:(resolution,fps)async{await state.startScreenShare(sourceId:own.single.id,captureScreenAudio:false,contentMode:ScreenShareContentMode.motion,quality:ScreenShareQuality(resolution:resolution,frameRate:fps));},
    setMode:(mode)async{state.updateScreenShareContentMode(mode=='text'?ScreenShareContentMode.text:ScreenShareContentMode.motion);},
    observe:(row)=>observe({'event':'lifecycle_acceptance',...row}),
    leave:state.leaveVoice,rejoin:()=>state.joinVoice(voice,listenerOnly:true),settle:()=>delay(3),
    snapshot:()=>{'profile':'P${state.screen.quality.resolution}_${state.screen.quality.frameRate}','selected_profile':state.screenShareSelectedProfileId,'mode':state.screenShareContentMode.name,'sharing':state.screenSharePhase==ScreenSharePhase.sharing,'restart_required':state.screen.captureRestartRequired,'same_initial_track':identical(initialTrack,state.screen.metrics.track),'live_track':state.screen.metrics.track!=null,'lease_replaced':state.voice.leaseId!=null&&state.voice.leaseId!=initialLease},
   );
   observe({'event':'lifecycle_acceptance_completed','step_count':result.length});
  }else if(mode=='restart'){
   await state.stopScreenShare();observe({'event':'rapid_stop'});await state.startScreenShare(sourceId:own.single.id,captureScreenAudio:false,contentMode:stageContentMode=='text'?ScreenShareContentMode.text:ScreenShareContentMode.motion,quality:stageMode?ScreenShareQuality(resolution:stageResolution,frameRate:stageRate):null);observe({'event':'republish_returned','screen_phase':state.screenSharePhase.name});await delay(10);
  }
  captureGeneration++;captureTimer?.cancel();await state.stopScreenShare();observe({'event':'publication_stopped','maximum_pending_reports':transport.maximumPendingReports,'pending_reports':transport.pendingReports,'maximum_pending_descriptors':transport.maximumPendingDescriptors,'pending_descriptors':transport.pendingDescriptors});
  final reportCount=rows.where((r)=>r['event']=='http_start').length;
  await delay(2);observe({'event':'post_stop_idle','new_reports':rows.where((r)=>r['event']=='http_start').length-reportCount,'pending_descriptors':transport.pendingDescriptors});
  await state.leaveVoice();phase='sender_complete';done=true;observe({'event':'sender_complete'});await writes;
 }catch(error){captureGeneration++;captureTimer?.cancel();phase='failed';done=true;observe({'event':'failed','error_type':error.runtimeType.toString()});await writes;}
}
class QaPattern extends StatefulWidget {const QaPattern({super.key});@override State<QaPattern> createState()=>_QaPatternState();}
class _QaPatternState extends State<QaPattern>{int tick=0;Timer? timer;@override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:100),(_){if(mounted)setState(()=>tick++);});}@override void dispose(){timer?.cancel();super.dispose();}@override Widget build(BuildContext context)=>ColoredBox(color:tick.isEven?Colors.deepPurple:Colors.teal,child:SizedBox(width:120,height:64,child:Center(child:Text('QA $tick',style:const TextStyle(color:Colors.white,fontSize:24)))));}
