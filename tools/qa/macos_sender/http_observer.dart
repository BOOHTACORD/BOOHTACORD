import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Observe real transport, never replace/fabricate backend responses.
class QaHttpObserver extends http.BaseClient {
  QaHttpObserver(this.delegate,this.observed,this.elapsedMs);
  final http.Client delegate;
  final void Function(Map<String,Object?>) observed;
  final double Function() elapsedMs;
  int pendingReports=0;
  int maximumPendingReports=0;
  @override Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final metrics=request.url.path=='/api/v1/voice/screen-metrics';
    Map<String,dynamic>? body;
    if(metrics && request is http.Request){try{body=jsonDecode(request.body) as Map<String,dynamic>;}catch(_) {}}
    if(!metrics || body?['direction']!='sender')return delegate.send(request);
    pendingReports++;if(pendingReports>maximumPendingReports)maximumPendingReports=pendingReports;
    final start=elapsedMs();
    final row=<String,Object?>{'event':'http_start','direction':'sender','at_ms':start,'pending':pendingReports};
    if(body!=null){
      for(final key in ['state','stats_source','collection_state','sample_age_ms','encoded_fps','capture_fps'])if(body.containsKey(key))row[key]=body[key];
    }
    observed(row);
    try {
      final response=await delegate.send(request);
      observed({'event':'http_response','at_ms':elapsedMs(),'duration_ms':elapsedMs()-start,'status':response.statusCode});
      return response;
    }catch(error){
      observed({'event':'http_error','at_ms':elapsedMs(),'duration_ms':elapsedMs()-start,'error_type':error.runtimeType.toString()});
      rethrow;
    }finally{pendingReports--;}
  }
  @override void close()=>delegate.close();
}
