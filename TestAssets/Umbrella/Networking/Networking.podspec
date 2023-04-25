Pod::Spec.new do |spec|
  spec.name         = "Networking"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of Networking."
  spec.description  = <<-DESC
    A long description of Networking
                   DESC
  spec.homepage     = "http://google.com/Networking"
  spec.license      = { :type => "MIT" }
  spec.author             = { "NinjaLikesCheez" => "NinjaLikesCheez@users.noreply.github.com" }
  spec.platform     = :ios, "16.0"
  spec.source       = { :git => "" }
  spec.source_files  = "Networking/**/*.{h,m,swift}"
  spec.public_header_files = "Networking/**/*.h"
end
