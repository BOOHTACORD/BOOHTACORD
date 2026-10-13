#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '1.6.2'
  s.summary          = 'Flutter WebRTC plugin for macOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_webrtc/Sources/flutter_webrtc/**/*.{h,m,mm}', '../common/darwin/Classes/{ScreenAudioSource.cc,ScreenAudioSource.h,ScreenAudioPCMConverter.h,ScreenAudioPCMConverter.mm,ScreenAudioTrackCapturer.h,ScreenAudioTrackCapturer.mm,RTCAudioSource+Private.h,audio_options.h,media_stream_interface.h}', '../common/rnnoise/rnnoise_capture_processor.{h,cc}', '../common/rnnoise/microphone_controls/processor.{h,cc}', '../common/rnnoise/public_include/*.h', '../common/rnnoise/upstream/include/*.h', '../common/rnnoise/upstream/src/*.{h,c}'
  s.exclude_files     = 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioSource.cc', 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioSource.h', 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioPCMConverter.mm', 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioPCMConverter.h', 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioTrackCapturer.mm', 'flutter_webrtc/Sources/flutter_webrtc/ScreenAudioTrackCapturer.h'
  s.public_header_files = 'flutter_webrtc/Sources/flutter_webrtc/include/flutter_webrtc/**/*.h'

  s.dependency 'FlutterMacOS'
  s.frameworks = 'CoreAudio'
  s.weak_frameworks = 'ScreenCaptureKit'
  s.dependency 'BoohtacordWebRTC', '150.7871.3'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../common/darwin/Classes" "${PODS_TARGET_SRCROOT}/../common/rnnoise/public_include" "${PODS_TARGET_SRCROOT}/../common/rnnoise/upstream/include"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/flutter_webrtc/Sources/flutter_webrtc/include/flutter_webrtc"'
  }
end
