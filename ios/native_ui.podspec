#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_ui.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_ui'
  s.version          = '0.0.1'
  s.summary          = 'Native iOS UI widgets for Flutter (native_platform_ui).'
  s.description      = <<-DESC
Native iOS UI for Flutter — buttons, switches, SF Symbols, liquid glass,
alerts, popovers, and bottom navigation via platform views.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', 'Widgets/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
  }
  # native_platform_ui requires iOS 15+ APIs (UIButton.Configuration).
  s.user_target_xcconfig = { 'IPHONEOS_DEPLOYMENT_TARGET' => '15.0' }
  s.swift_version = '5.0'
end
