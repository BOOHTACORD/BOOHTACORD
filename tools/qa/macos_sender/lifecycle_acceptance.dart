/// Bounded, public-safe checks of the existing native macOS lifecycle APIs.
Future<List<Map<String,Object?>>> runQaLifecycleAcceptance({
 required Future<void> Function(int resolution,int fps) update,
 required Future<void> Function() stop,
 required Future<void> Function(int resolution,int fps) start,
 required Future<void> Function() leave,
 required Future<void> Function() rejoin,
 required Future<void> Function(String mode) setMode,
 required Map<String,Object?> Function() snapshot,
 required Future<void> Function() settle,
 required void Function(Map<String,Object?>) observe,
}) async {
 final rows=<Map<String,Object?>>[];
 void check(String step,Map<String,Object?> expected){
  final actual=snapshot();
  final passed=expected.entries.every((entry)=>actual[entry.key]==entry.value);
  final row=<String,Object?>{'step':step,'assertions_passed':passed,for(final key in ['profile','selected_profile','mode','sharing','restart_required','same_initial_track','live_track','lease_replaced'])key:actual[key]};
  observe(row);rows.add(row);
  if(!passed)throw StateError('QA lifecycle state assertion failed');
 }
 await setMode('text');await settle();check('compatible_mode',{'profile':'P1080_60','mode':'text','sharing':true,'restart_required':false,'same_initial_track':true,'live_track':true});
 await setMode('motion');await settle();
 await update(720,30);check('lower_restart_required',{'profile':'P1080_60','selected_profile':'P720_30','sharing':true,'restart_required':true,'same_initial_track':true,'live_track':true});
 await stop();await start(720,30);await settle();check('lower_restart_completed',{'profile':'P720_30','sharing':true,'restart_required':false,'same_initial_track':false,'live_track':true});
 await update(1080,60);check('higher_restart_required',{'profile':'P720_30','selected_profile':'P1080_60','sharing':true,'restart_required':true,'live_track':true});
 await stop();await start(1080,60);await settle();check('higher_restart_completed',{'profile':'P1080_60','sharing':true,'restart_required':false,'live_track':true});
 await stop();await leave();await rejoin();await start(1080,60);await settle();check('lease_rejoin_completed',{'profile':'P1080_60','sharing':true,'restart_required':false,'live_track':true,'lease_replaced':true});
 return rows;
}
