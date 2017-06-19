Pod::Spec.new do |s|
  s.name = "Wave"
  s.version = "0.2.2"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.summary = "Audio Player Library"
  s.homepage = "https://github.com/XWJACK/Wave"
  s.author = { "Jack" => "xuwenjiejack@gmail.com" }
  s.source = { :git => "https://github.com/XWJACK/Wave.git", :tag => s.version }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  
  s.source_files  = ["Sources/*.swift", "Sources/Wave.h"]
  s.public_header_files = ["Sources/Wave.h"]

  s.requires_arc = true
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.0' }
end
