import 'package:flutter_test/flutter_test.dart';
import '../integration_test/qa98325_lifecycle_acceptance.dart';
void main(){
 test('Mac static capture limits require owned restart in either direction and report failed snapshots',()async{
  final steps=<String>[],observed=<Map<String,Object?>>[];
  var profile='P1080_60',selected=profile,restart=false,initial=true,sharing=true,leaseReplaced=false,mode='motion';
  Map<String,Object?> snapshot()=>{'profile':profile,'selected_profile':selected,'mode':mode,'sharing':sharing,'restart_required':restart,'same_initial_track':initial,'live_track':sharing,'lease_replaced':leaseReplaced};
  Future<void> update(int resolution,int fps)async{steps.add('update:$resolution:$fps');selected='P${resolution}_$fps';restart=true;}
  Future<void> stop()async{steps.add('stop');sharing=false;}
  Future<void> start(int resolution,int fps)async{steps.add('start:$resolution:$fps');profile='P${resolution}_$fps';selected=profile;sharing=true;restart=false;initial=false;}
  final result=await runQaLifecycleAcceptance(update:update,stop:stop,start:start,leave:()async{steps.add('leave');sharing=false;},rejoin:()async{steps.add('rejoin');leaseReplaced=true;},setMode:(value)async{mode=value;},snapshot:snapshot,settle:()async{},observe:observed.add);
  expect(result.map((e)=>e['step']),['compatible_mode','lower_restart_required','lower_restart_completed','higher_restart_required','higher_restart_completed','lease_rejoin_completed']);
  expect(steps,['update:720:30','stop','start:720:30','update:1080:60','stop','start:1080:60','stop','leave','rejoin','start:1080:60']);
  expect(observed.every((e)=>e['assertions_passed']==true),true);
  observed.clear();
  await expectLater(runQaLifecycleAcceptance(update:(_,_)async{},stop:stop,start:start,leave:()async{},rejoin:()async{},setMode:(_)async{},snapshot:()=>{'profile':'P1080_60','selected_profile':'P1080_60','mode':'motion','sharing':true,'restart_required':false,'same_initial_track':true,'live_track':true,'password':'PRIVATE'},settle:()async{},observe:observed.add),throwsStateError);
  expect(observed.single['step'],'compatible_mode');expect(observed.single['assertions_passed'],false);expect(observed.single.containsKey('password'),false);
 });
}
