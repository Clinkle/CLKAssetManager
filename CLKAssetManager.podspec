Pod::Spec.new do |s|
  s.name             = "CLKAssetManager"
  s.version          = "0.1.2"
  s.summary          = "The best way to reduce your iOS app binary by safely downloading binary assets at most once"
  s.homepage         = "https://github.com/Clinkle/CLKAssetManager"
  s.license          = 'Apache'
  s.author           = { "tsheaff" => "tyler@clinkle.com" }
  s.source           = { :git => "https://github.com/Clinkle/CLKAssetManager.git", :tag => s.version.to_s }

  s.dependency 'CLKModel', '~> 0.1.1'
  s.dependency 'CLKSingletons', '~> 0.1.1'
  s.dependency 'AFNetworking', '~> 2.5.1'

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes'
end
