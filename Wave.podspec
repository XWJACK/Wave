Pod::Spec.new do |s|
  s.name = "Wave"
  s.version = "0.2.2"
  s.license = 'MIT'
  s.summary = "XWJACK Audio Player Library"
  s.homepage = "https://github.com/XWJACK/Wave"
  s.author = { "Jack" => "xuwenjiejack@gmail.com" }
  s.source = { :git => "https://github.com/XWJACK/Wave.git", :tag => s.version }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  
  s.source_files = 'Sources/*.swift'

  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.0' }
end
