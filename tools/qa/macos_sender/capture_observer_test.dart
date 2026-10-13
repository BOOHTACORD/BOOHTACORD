import 'package:flutter_test/flutter_test.dart';

import '../integration_test/qa98325_capture_observer.dart';

void main() {
  test('v3 queue and processing operation counters retain unknown without private fields',(){
    final out=sanitizeCaptureSnapshot({'schema_version':1,'queue_depth':1,'peak_queue_depth':1,'in_flight':1,'peak_in_flight':1,'queue_age_ms':2.5,'maximum_queue_age_ms':3.5,'native_resize_frames':60,'i420_scale_frames':0,'buffer_pool_creations':1,'buffer_pool_acquisitions':60,'pool_buffers_first_seen':3,'processing_failures':0,'pass_through_frames':0,'heap_allocations':null,'capture_timestamp_latency_ms':null,'private_title':'private'});
    expect(out['buffer_pool_acquisitions'],60);expect(out['native_resize_frames'],60);expect(out['queue_depth'],1);expect(out['heap_allocations'],null);expect(out.containsKey('private_title'),false);
  });
  test('actual frozen bridge engine enums retain native provenance', () {
    for (final engine in ['rtc_desktop_capturer', 'screen_capture_kit']) {
      expect(
        sanitizeCaptureSnapshot({
          'schema_version': 1,
          'status': 'pending',
          'engine': engine,
        })['engine'],
        engine,
      );
    }
  });
  test('bounded capture export rejects private and unknown fields', () {
    final result = sanitizeCaptureSnapshot({
      'schema_version': 1,
      'status': 'active',
      'engine': 'legacy-window',
      'source_class': 'window',
      'accepted_frames': 60,
      'private_title': 'do not export',
      'trackId': 'private',
      'drop_reasons': {'idle': 2, 'private': 42},
      'frame_age_basis': 'native_monotonic_since_latest_accepted_callback',
    });
    expect(result['accepted_frames'], 60);
    expect(result.containsKey('private_title'), false);
    expect(result.containsKey('trackId'), false);
    expect(result['drop_reasons'], {'idle': 2});
  });
  test('unsupported capture snapshot stays unknown not zero', () {
    expect(sanitizeCaptureSnapshot({})['status'], 'unavailable');
    expect(sanitizeCaptureSnapshot({})['accepted_frames'], isNull);
    expect(
      sanitizeCaptureSnapshot({
        'schema_version': 1,
        'status': 'active',
        'accepted_frames': -1,
      })['accepted_frames'],
      isNull,
    );
  });
}
