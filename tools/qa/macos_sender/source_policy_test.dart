import 'package:flutter_test/flutter_test.dart';
import '../integration_test/qa98325_source_policy.dart';
void main(){test('interactive receiver original review has its own bounded deadline; fault actions remain short',(){expect(qaControlPollCount('review_receiver'),720);for(final action in ['verify_fullscreen_display','pause_api','stop_api','enable_metadata_fault'])expect(qaControlPollCount(action),200);expect(()=>qaControlPollCount('unbounded'),throwsStateError);});test('explicit content intent rejects unknown selectors without changing FPS',(){expect(qaContentMode(null),'motion');expect(qaContentMode('text'),'text');expect(()=>qaContentMode('adaptive'),throwsStateError);});test('unsupported explicit publish duration fails before media rather than falling back',(){expect(qaPublishDuration(null,fallback:16),16);expect(qaPublishDuration('120',fallback:16),120);for(final value in ['121','300','bad','9']){expect(()=>qaPublishDuration(value,fallback:16),throwsStateError);}});test('displaycapture requires fullscreen ownsynthetic originalreview and oneexactdisplay',(){
 expect(allowDisplayCapture(stage:true,fullscreen:true,reviewed:true,displayCount:1),true);
 for(final row in [(false,true,true,1),(true,false,true,1),(true,true,false,1),(true,true,true,2),(true,true,true,0)]){
  expect(allowDisplayCapture(stage:row.$1,fullscreen:row.$2,reviewed:row.$3,displayCount:row.$4),false);
 }
});}
