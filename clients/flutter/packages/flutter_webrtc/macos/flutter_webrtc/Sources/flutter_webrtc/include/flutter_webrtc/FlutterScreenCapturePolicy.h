#ifndef FlutterScreenCapturePolicy_h
#define FlutterScreenCapturePolicy_h

#import <Foundation/Foundation.h>

// Availability is decided by the caller before selecting the native route.
// Unsupported systems retain the exact selected window through WebRTC.
static inline BOOL FlutterScreenCaptureKitWindowRequested(
    NSString *engine, BOOL supported) {
  return supported && [engine isEqualToString:@"screen_capture_kit"];
}

#endif
