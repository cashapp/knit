Pod::Spec.new do |s|
  s.name             = 'Knit'
  s.version          = '0.2.6'
  s.summary          = 'A tool for adding safety features to Swinject'
  s.description      = 'Knit parses Swinject code and generates Swift files for type safety and unit testing.'
  s.homepage         = 'https://github.com/squareup/knit'
  s.license          = { :type => 'Proprietary', :text => '© Square, Inc.' }
  s.author           = { 'Cash App iOS' => 'ios@squareup.com' }

  # TODO: Update this endpoint to be GitHub once this repository is public.
  s.source           = { http: "https://artifactory.global.square/artifactory/squarepods/knit-#{s.version}.zip" }

  s.source_files     = 'Sources/Knit/**/*.swift'
  s.preserve_paths   = '*'
  s.ios.deployment_target = '14.0'
  s.dependency 'Swinject', '2.8.3'
  s.dependency 'SwinjectAutoregistration', '2.8.3'
end
