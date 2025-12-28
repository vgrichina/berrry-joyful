# Podfile for berrry-joyful

platform :osx, '14.0'

target 'berrry-joyful' do
  use_frameworks!

  # JoyConSwift - IOKit wrapper for Nintendo Joy-Con and ProController
  pod 'JoyConSwift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
