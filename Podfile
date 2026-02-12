# Podfile for Enclosure - Native WebRTC Implementation
platform :ios, '14.0'

target 'Enclosure' do
  use_frameworks!

  # Firebase (already using)
  pod 'Firebase/Database'
  pod 'Firebase/Auth'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'
  
  # Google WebRTC - Native calling
  pod 'GoogleWebRTC', '~> 1.1'
  
  # Existing dependencies
  pod 'Alamofire', '~> 5.6'
  pod 'SDWebImageSwiftUI', '~> 2.2'
  
end

target 'EnclosureNotificationService' do
  use_frameworks!
  
  pod 'Firebase/Messaging'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
