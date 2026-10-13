import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../integration_test/qa98325_http_observer.dart';
class HoldingClient extends http.BaseClient {
 final replies=<Completer<http.StreamedResponse>>[];
 final requests=<http.BaseRequest>[];
 @override Future<http.StreamedResponse> send(http.BaseRequest request){requests.add(request);final reply=Completer<http.StreamedResponse>();replies.add(reply);return reply.future;}
 @override void close(){}
}
void main(){
 test('metadata HTTP receipt keeps only bounded public fields and originalrequest',() async {
  final client=HoldingClient(),rows=<Map<String,Object?>>[];final observer=QaHttpObserver(client,rows.add,()=>10);
  final request=http.AbortableRequest('PUT',Uri.parse('https://localhost:5060/api/v1/voice/leases/private-lease/screen-profile/v1'))..body='{"schema_version":1,"mode":"motion","requested_profile_id":"P1080_60","profile_revision":2,"scope":{"account_id":"private-account","origin_id":"private-origin","publication_generation":1,"operation_revision":3},"publisher_state":"sharing"}';
  final response=observer.send(request);
  expect(client.requests.single,same(request));expect(rows.single['event'],'descriptor_http_start');expect(rows.single['profile_revision'],2);expect(rows.single['publication_generation'],1);
  expect(rows.single.toString(),isNot(contains('private')));expect(rows.single.containsKey('scope'),false);
  client.replies.single.complete(http.StreamedResponse(const Stream.empty(),204));await response;
  expect(rows.last['event'],'descriptor_http_response');expect(rows.last['status'],204);expect(observer.pendingDescriptors,0);
 });
 test('metadata retry receipts compare complete previous request privately and expose equality only',()async{
  final client=HoldingClient(),rows=<Map<String,Object?>>[];final observer=QaHttpObserver(client,rows.add,()=>10);
  for(final body in ['{"schema_version":1,"scope":{"account_id":"PRIVATE"}}','{"schema_version":1,"scope":{"account_id":"PRIVATE"}}','{"schema_version":1,"scope":{"account_id":"CHANGED"}}']){
   final response=observer.send(http.Request('PUT',Uri.parse('https://localhost:5060/api/v1/voice/leases/private-lease/screen-profile/v1'))..body=body);
   client.replies.last.complete(http.StreamedResponse(const Stream.empty(),503));await response;
  }
  final starts=rows.where((r)=>r['event']=='descriptor_http_start').toList();expect(starts.map((r)=>r['same_body_as_previous']),[null,true,false]);expect(rows.toString(),isNot(contains('PRIVATE')));expect(rows.toString(),isNot(contains('CHANGED')));
 });
 test('QA HTTP observer separates sender from local-preview receiver and preserves AbortableRequest',() async {
 final client=HoldingClient(),rows=<Map<String,Object?>>[];final observer=QaHttpObserver(client,rows.add,()=>10);
 final aborted=Completer<void>();
 final sender=http.AbortableRequest('POST',Uri.parse('https://localhost:5060/api/v1/voice/screen-metrics'),abortTrigger:aborted.future)..body='{"direction":"sender","state":"waiting_first_frame","voice_lease_id":"fixture-not-for-output"}';
 final receiver=http.Request('POST',sender.url)..body='{"direction":"receiver","state":"playing"}';
 final a=observer.send(sender),b=observer.send(receiver);
 expect(client.requests.first,same(sender));
 expect(observer.maximumPendingReports,1);
 expect(rows,hasLength(1));expect(rows.single['direction'],'sender');expect(rows.single.containsKey('voice_lease_id'),false);
 for(final reply in client.replies){reply.complete(http.StreamedResponse(const Stream.empty(),204));}
 await Future.wait([a,b]);expect(observer.pendingReports,0);expect(rows,hasLength(2));
 });}
