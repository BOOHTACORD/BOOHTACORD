import 'package:flutter_test/flutter_test.dart';
import '../integration_test/qa98325_descriptor_observer.dart';
enum QaWriteStatus { pending, applied, unavailable, foreign }
void main(){test('descriptor status reads Enum.name through a typed boundary',(){for(final value in [QaWriteStatus.pending,QaWriteStatus.applied,QaWriteStatus.unavailable]){final dynamic raw=value;expect(publicDescriptorStatus(raw),value.name);}expect(publicDescriptorStatus(QaWriteStatus.foreign),null);expect(publicDescriptorStatus('applied'),null);});
 test('descriptor diagnostic retains bounded revisions and profile but removesidentity',(){
  final row=publicDescriptorFields({'schema_version':1,'mode':'motion','requested_profile_id':'P1080_60','publisher_state':'sharing','profile_revision':2,'scope':{'account_id':'private','origin_id':'private','media_session_id':'private','publication_generation':1,'operation_revision':3},'effective_profile':{'capture':{'max_width':1920,'max_height':1080,'max_fps':60},'encoding':{'codec':'VP8','layers':[{'rid':'private','width':1920,'height':1080,'max_fps':60,'max_bitrate_bps':8000000,'scale_down_by':1.0,'active':true}]}}});
  expect(row['profile_revision'],2);expect(row['publication_generation'],1);expect(row['operation_revision'],3);expect(row.toString(),isNot(contains('private')));expect(row.containsKey('scope'),false);
 });
 test('unknown descriptor stays unknown without zero/defaultlimits',(){
  final row=publicDescriptorFields(null);expect(row['descriptor_present'],false);expect(row.containsKey('profile_revision'),false);expect(row.containsKey('effective_profile'),false);
 });
}
