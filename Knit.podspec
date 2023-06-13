Pod::Spec.new do |s|
  s.name             = 'Knit'
  s.version          = '0.0.2'
  s.summary          = 'A tool for adding safety features to Swinject'
  s.description      = 'Knit parses Swinject code and generates Swift files for type safety and unit testing.'
  s.homepage         = 'https://github.com/squareup/knit'
  s.license          = { :type => 'Proprietary', :text => '© Square, Inc.' }
  s.author           = { 'Cash App iOS' => 'ios@squareup.com' }
  s.source           = { :git => 'org-49461806@github.com:squareup/knit.git', :tag => s.version.to_s }
  s.ios.deployment_target = '14.0'
  s.source_files = 'Sources/Knit/**/*.swift'
  s.dependency 'Swinject', '2.8.3'
  s.dependency 'SwinjectAutoregistration', '2.8.3'
end
