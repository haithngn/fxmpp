Pod::Spec.new do |s|
  s.name             = 'fxmpp'
  s.version          = '0.1.0'
  s.summary          = 'A Flutter plugin for XMPP communication'
  s.description      = <<-DESC
A Flutter plugin for XMPP (Extensible Messaging and Presence Protocol) communication, 
supporting both iOS and Android platforms with real-time messaging capabilities.
                       DESC
  s.homepage         = 'https://hainguyen.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hai Nguyen' => 'hai@hainguyen.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'XMPPFramework', '~> 4.0'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
