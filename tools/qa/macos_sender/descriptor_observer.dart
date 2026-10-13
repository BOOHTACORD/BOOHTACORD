/// Public-safe QA projection of the existing v1 descriptor; never exportscopeIDs.
Map<String,Object?> publicDescriptorFields(Map<dynamic,dynamic>? raw){
 if(raw==null||raw['schema_version']!=1)return {'descriptor_present':false};
 const profiles={'P720_15','P720_30','P720_60','P1080_15','P1080_30','P1080_60','P1440_15','P1440_30','P1440_60'};
 final out=<String,Object?>{'descriptor_present':true,'schema_version':1};
 if(const{'motion','text'}.contains(raw['mode']))out['mode']=raw['mode'];
 if(profiles.contains(raw['requested_profile_id']))out['requested_profile_id']=raw['requested_profile_id'];
 if(const{'idle','requesting','capturing','publishing','sharing','updating','stopping','failed'}.contains(raw['publisher_state']))out['publisher_state']=raw['publisher_state'];
 num? number(Object? v,num max)=>v is num&&v.isFinite&&v>=0&&v<=max?v:null;
 out['profile_revision']=number(raw['profile_revision'],9007199254740991);
 final scope=raw['scope'];if(scope is Map)for(final key in ['publication_generation','operation_revision'])out[key]=number(scope[key],9007199254740991);
 final effective=raw['effective_profile'];if(effective is Map){
  final capture=effective['capture'],encoding=effective['encoding'];
  out['effective_profile']={'capture':{if(capture is Map)for(final key in ['max_width','max_height','max_fps'])key:number(capture[key],16384)},'encoding':{'codec':encoding is Map&&const{'VP8','H264','VP9','AV1'}.contains(encoding['codec'])?encoding['codec']:null,'layers':[if(encoding is Map&&encoding['layers'] is List)for(final layer in (encoding['layers'] as List).take(2))if(layer is Map){for(final key in ['width','height','max_fps','max_bitrate_bps','scale_down_by'])key:number(layer[key],100000000),'active':layer['active'] is bool?layer['active']:null}]}};
 }
 return out;
}

String? publicDescriptorStatus(Object? status){if(status is! Enum)return null;final name=status.name;return const{'pending','applied','unavailable'}.contains(name)?name:null;}
