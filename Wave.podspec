Pod::Spec.new do |s|

  s.name         = "Wave"
  s.version      = "0.2.1"
  s.summary      = "XWJACK Audio Player Library"

  s.homepage     = "https://github.com/XWJACK/Wave"
  s.author       = { "Jack" => "xuwenjiejack@gmail.com" }

  s.ios.deployment_target  = "8.0"
  s.osx.deployment_target = "10.9"

  s.source       = { :git => "https://github.com/XWJACK/Wave.git", :tag => s.version }

  s.source_files  = ["Sources/*.swift"]
  s.public_header_files = ["Sources/Wave.h"]

  s.requires_arc = true

end
