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
void main(){test('QA HTTP observer separates sender from local-preview receiver and preserves AbortableRequest',() async {
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
