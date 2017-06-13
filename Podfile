platform :ios,'8.0'
use_frameworks!
inhibit_all_warnings!

pre_install do |installer|
    def installer.verify_no_static_framework_transitive_dependencies;
    end
end

target 'HDNewHouseDemo' do

#网络请求
    pod 'AFNetworking'

#网络请求数据使用PINCache缓存
    pod 'PINCache'


end
