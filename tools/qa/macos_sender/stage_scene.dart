import 'dart:math' as math;
import 'package:flutter/material.dart';

List<bool> stageMarkerBits(int frame) => [
 for(var bit=0;bit<8;bit++) (0xa6 & (1<<bit))!=0,
 for(var bit=0;bit<12;bit++) ((frame &4095)&(1<<bit))!=0,
];
class StageFrameLedger {
 int vsyncCallbacks=0,paintAttempts=0,sourceUpdates=0;
 int _bucket=-1;
 double? width,height;
 final List<int> _times=[];
 int get retainedFrames=>_times.length;
 bool vsync(int microseconds){vsyncCallbacks++;_times.add(microseconds);if(_times.length>120)_times.removeAt(0);final bucket=microseconds~/16667;if(bucket==_bucket)return false;_bucket=bucket;sourceUpdates++;return true;}
 void painted(){paintAttempts++;}
 Map<String,Object?> snapshot(){
  final gaps=[for(var i=1;i<_times.length;i++)(_times[i]-_times[i-1])/1000]..sort();
  return {'vsync_callbacks':vsyncCallbacks,'paint_attempts':paintAttempts,'source_updates':sourceUpdates,'logical_width':width,'logical_height':height,'retained_vsync_events':_times.length,'recent_vsync_gap_ms_p95':gaps.isEmpty?null:gaps[(gaps.length*.95).ceil()-1],'observation':'FlutterTicker/CustomPainter only; not accepted native capture or monitor scanout'};
 }
}
class SyntheticStageScene extends StatefulWidget {
 const SyntheticStageScene({super.key,required this.ledger,required this.staticScene,required this.profileResolution});
 final StageFrameLedger ledger;final bool staticScene;final int profileResolution;
 @override State<SyntheticStageScene> createState()=>_SyntheticStageSceneState();
}
class _SyntheticStageSceneState extends State<SyntheticStageScene> with SingleTickerProviderStateMixin {
 late final ticker=createTicker((elapsed){if(widget.ledger.vsync(elapsed.inMicroseconds))setState((){});});
 @override void initState(){super.initState();if(!widget.staticScene)ticker.start();}
 @override void dispose(){ticker.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>CustomPaint(painter:_StagePainter(widget.ledger,widget.profileResolution),size:Size.infinite);
}
class _StagePainter extends CustomPainter {
 _StagePainter(this.ledger,this.resolution);final StageFrameLedger ledger;final int resolution;
 @override void paint(Canvas canvas,Size size){
  ledger.painted();ledger.width=size.width;ledger.height=size.height;
  canvas.drawRect(Offset.zero&size,Paint()..color=const Color(0xff102030));
  for(var i=0;i<12;i++){
   final x=(ledger.sourceUpdates*4+i*97)%math.max(1,size.width.toInt());
   canvas.drawRect(Rect.fromLTWH(x.toDouble(),210+(i%4)*55,70,40),Paint()..color=Color.fromARGB(255,40+i*15,200-i*9,80+i*12));
  }
  for(var x=0.0;x<size.width;x+=20)canvas.drawLine(Offset(x,420),Offset(x,size.height),Paint()..color=Colors.white24..strokeWidth=1);
  final text=TextPainter(text:TextSpan(text:'SYNTHETIC QA329332  frame ${ledger.sourceUpdates &4095}\n0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ fine geometry / scrolling reference',style:const TextStyle(color:Colors.white,fontSize:18)),textDirection:TextDirection.ltr)..layout(maxWidth:size.width-30);text.paint(canvas,const Offset(16,16));
  // Physical source geometry is checked at the receiver. This coordinate scale
  // is a requested mapping, not evidence of capture dimensions or FPS.
  final scale=resolution/720.0,x=32/scale,y=128/scale,cell=24/scale;
  canvas.drawRect(Rect.fromLTWH(x-4/scale,y-4/scale,5*cell+8/scale,4*cell+8/scale),Paint()..color=const Color(0xffff00ff));
  final bits=stageMarkerBits(ledger.sourceUpdates);
  for(var i=0;i<bits.length;i++)canvas.drawRect(Rect.fromLTWH(x+(i%5)*cell,y+(i~/5)*cell,cell,cell),Paint()..color=bits[i]?Colors.white:Colors.black);
 }
 @override bool shouldRepaint(covariant _StagePainter old)=>true;
}
