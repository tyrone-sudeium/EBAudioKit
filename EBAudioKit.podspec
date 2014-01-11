Pod::Spec.new do |s|
  s.name = "EBAudioKit"
  s.version = "0.1"
  s.summary = "Streaming, caching, queueing, backgroundable, Opus-based audio player for iOS"
  s.homepage = "http://www.opus-codec.org"
  s.license = 'MIT'
  s.authors = { "Tyrone Trevorrow" => "tyrone@sudeium.com", "Xiph.org" => "opus@xiph.org"}
  s.source = { :git => "https://github.com/tyrone-sudeium/EBAudioKit.git", :tag => '0.1'}
  s.ios.deployment_target = '6.0' # We're compiling arm64, so I think 6.0 minimum is needed
  s.source_files = 'EBAudioKit/**/*.{h,m}'
  s.public_header_files = 'EBAudioKit/Public/*.h'
  s.requires_arc = true
  s.frameworks = 'AudioToolbox', 'CoreMedia'
  s.dependency 'libopusfile-ios', '~> 0.4'
  s.dependency 'libopus-ios', '~> 1.1'
  s.dependency 'AFNetworking', '~> 2.0'
  s.dependency 'TheAmazingAudioEngine', '~> 1.2'
end