Pod::Spec.new do |spec|
  spec.name         = "Common"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of Common."
  spec.description  = <<-DESC
    A longer description of Common
                   DESC
  spec.homepage     = "http://google.com/Common"
  spec.license      = { :type => "MIT" }
  spec.author             = { "NinjaLikesCheez" => "NinjaLikesCheez@users.noreply.github.com" }
  spec.platform     = :ios, "16.0"
  spec.source       = { :git => "" }
  spec.source_files  = "Common/**/*.{h,m,swift}"
  spec.public_header_files = "Common/**/*.h"
end
