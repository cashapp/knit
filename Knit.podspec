Pod::Spec.new do |s|
  s.name             = 'Knit'
  s.version          = '1.0.0'
  s.summary          = 'A tool for adding safety features to Swinject'
  s.description      = 'Knit parses Swinject code and generates Swift files for type safety and unit testing.'
  s.homepage         = 'https://github.com/cashapp/knit'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Cash App' => 'https://github.com/cashapp' }

  s.source           = { http: "https://github.com/cashapp/knit/releases/download/#{s.version}/knit-#{s.version}.zip" }

  s.source_files     = 'Sources/Knit/**/*.swift'
  s.preserve_paths   = '*'
  s.ios.deployment_target = '15.0'
  s.dependency 'Swinject', '~> 2.9.1'
  s.dependency 'SwinjectAutoregistration', '~> 2.8.4'
end
