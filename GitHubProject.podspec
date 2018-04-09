#
# Be sure to run `pod lib lint GitHubProject.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GitHubProject'
  s.version          = '0.1.5'
  s.summary          = 'A short description of GitHubProject.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'github上的测试类 GitHubProject.'

  s.homepage         = 'https://github.com/defuliu/PrivatePod'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'defuliu' => 'liudefu@china.zhaogang.com' }
  s.source           = { :git => 'https://github.com/defuliu/PrivatePod.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  #s.source_files = 'GitHubProject/Classes/**/*'
  s.subspec 'ZGDB' do |zgdb|
   zgdb.source_files = 'GitHubProject/Classes/Zgdb/**/*.{swift,h,m,c}'
   zgdb.public_header_files = 'FMDB/src/fmdb/FMDB.h'
   #zgdb.dependency 'FMDB'
  end
  
  # s.resource_bundles = {
  #   'GitHubProject' => ['GitHubProject/Assets/*.png']
  # }
    s.dependency 'FMDB'
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
