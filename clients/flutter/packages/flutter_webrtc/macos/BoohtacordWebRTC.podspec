Pod::Spec.new do |s|
  s.name = 'BoohtacordWebRTC'
  s.version = '150.7871.3'
  s.summary = 'Pinned macOS WebRTC with isolated custom screen-audio routing.'
  s.homepage = 'https://github.com/Egkurilov/BOOHTACORD'
  s.license = { :type => 'BSD-3-Clause', :file => 'WebRTC.xcframework/LICENSE' }
  s.author = 'The WebRTC project authors and BOOHTACORD contributors'
  s.source = {
    :http => 'https://github.com/Egkurilov/BOOHTACORD/releases/download/webrtc-m150-boohtacord-r2/WebRTC-macos.xcframework.zip',
    :sha256 => '0617e131f303f4a76acbdcf4f9538fc1e359fc56e7ba1234f3e8bda40bc23de2'
  }
  s.osx.deployment_target = '10.15'
  s.module_name = 'WebRTC'
  s.vendored_frameworks = 'WebRTC.xcframework'
  s.libraries = 'c++'
end
