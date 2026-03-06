# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'Enclosure' do
  # Static linking — avoids Pods_Enclosure.framework umbrella
  # (GoogleWebRTC has no simulator slices, so dynamic umbrella can't build for sim)

  # WebRTC for native voice calls
  pod 'GoogleWebRTC', '~> 1.0.136171'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      # Skip building pods for simulator (GoogleWebRTC has no simulator slices)
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64 x86_64 i386'
    end
  end
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
  end

  # Modify xcconfig: move WebRTC linking to device-only
  # GoogleWebRTC has no simulator slices — must NOT link on simulator
  xcconfig_dir = File.join(installer.sandbox.root, 'Target Support Files', 'Pods-Enclosure')
  Dir.glob(File.join(xcconfig_dir, '*.xcconfig')).each do |xcconfig_path|
    xcconfig = File.read(xcconfig_path)

    # Remove -framework "WebRTC" from default OTHER_LDFLAGS
    if xcconfig.include?('-framework "WebRTC"')
      xcconfig = xcconfig.gsub(' -framework "WebRTC"', '')
    end

    # Remove GoogleWebRTC search paths from default settings
    xcconfig = xcconfig.gsub(/ "\$\{PODS_ROOT\}\/GoogleWebRTC\/Frameworks\/frameworks"/, '')
    xcconfig = xcconfig.gsub(/ "\$\{PODS_CONFIGURATION_BUILD_DIR\}\/GoogleWebRTC"/, '')
    xcconfig = xcconfig.gsub(/ "-F\$\{PODS_CONFIGURATION_BUILD_DIR\}\/GoogleWebRTC"/, '')

    # Add device-only entries for WebRTC
    unless xcconfig.include?('sdk=iphoneos')
      xcconfig += "\n// WebRTC only on device (no simulator slices)\n"
      xcconfig += "OTHER_LDFLAGS[sdk=iphoneos*] = $(inherited) -framework \"WebRTC\"\n"
      xcconfig += "FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*] = $(inherited) \"${PODS_ROOT}/GoogleWebRTC/Frameworks/frameworks\"\n"
    end

    File.write(xcconfig_path, xcconfig)
  end
end

# post_integrate runs AFTER CocoaPods integrates with the user project.
# This is critical — post_install runs BEFORE integration, so any pbxproj
# changes made there get overwritten when CocoaPods re-adds the library.
post_integrate do |installer|
  # Remove libPods-Enclosure.a from main target's frameworks build phase.
  # WebRTC linking is handled by xcconfig (device-only via [sdk=iphoneos*]).
  # Without this, simulator builds fail because the static lib can't be built.
  project_path = File.join(Dir.pwd, 'Enclosure.xcodeproj')
  project = Xcodeproj::Project.open(project_path)
  main_target = project.targets.find { |t| t.name == 'Enclosure' }
  if main_target
    frameworks_phase = main_target.frameworks_build_phase
    to_remove = frameworks_phase.files.select { |f|
      f.display_name.include?('Pods-Enclosure') || f.display_name.include?('Pods_Enclosure')
    }
    to_remove.each { |f| frameworks_phase.remove_build_file(f) }
    project.save if to_remove.any?
    puts "[Podfile] Removed #{to_remove.count} Pods library reference(s) from Enclosure frameworks build phase"
  end
end
