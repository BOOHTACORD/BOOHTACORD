/// Display capture is allowed only after review of the single own fullscreen scene.
bool allowDisplayCapture({required bool stage,required bool fullscreen,required bool reviewed,required int displayCount})=>stage&&fullscreen&&reviewed&&displayCount==1;

int qaPublishDuration(String? explicit,{required int fallback}){if(explicit==null)return fallback;final value=int.tryParse(explicit);if(value==null||value<10||value>120)throw StateError('QA prototype publish duration must be 10..120 seconds');return value;}
String qaContentMode(String? explicit){if(explicit==null)return 'motion';if(explicit!='motion'&&explicit!='text')throw StateError('Bounded QA content mode required');return explicit;}

int qaControlPollCount(String action){if(action=='review_receiver')return 720;if(const{'verify_fullscreen_display','pause_api','stop_api','enable_metadata_fault'}.contains(action))return 200;throw StateError('Bounded own QA control action required');}
