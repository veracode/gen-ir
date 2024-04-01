#
# this is a minimal cmake project for an iOS app
#	don't really care if it makes a functioning iOS app, just that we get something created for gen-ir to work on
#	the real purpose of this test is verifying that gen-ir can handle cmake's alternate build directory
#
cmake_minimum_required(VERSION 3.27)

set(DEVELOPMENT_PROJECT_NAME "cmake-test")                     # <== Set to your project name, e.g. project.xcodeproj
set(DEVELOPMENT_TEAM_ID "AAAAAAAAAA")                       # <== Set to your team ID from Apple
set(APP_NAME "TEST_APP")                                     # <== Set To your app's name
set(APP_BUNDLE_IDENTIFIER "com.company.app")                # <== Set to your app's bundle identifier
set(FRAMEWORK_NAME "FooBar")                                # <== Set to your framework's name
set(FRAMEWORK_BUNDLE_IDENTIFIER "com.company.framework")    # <== Set to your framework's bundle identifier (cannot be the same as app bundle identifier)
set(TEST_NAME "Tests")                                      # <== Set to your test's name
set(TEST_BUNDLE_IDENTIFIER "com.company.tests")             # <== Set to your tests's bundle ID
set(CODE_SIGN_IDENTITY "iPhone Developer")                  # <== Set to your preferred code sign identity, to see list:
															# /usr/bin/env xcrun security find-identity -v -p codesigning
set(DEPLOYMENT_TARGET 17.0)                                 # <== Set your deployment target version of iOS
set(DEVICE_FAMILY "1,2")                                      # <== Set to "1" to target iPhone, set to "2" to target iPad, set to "1,2" to target both
set(LOGIC_ONLY_TESTS 0)                                     # <== Set to 1 if you do not want tests to be hosted by the application, speeds up pure logic tests but you can not run them on real devices

project(${DEVELOPMENT_PROJECT_NAME})

set(PRODUCT_NAME ${APP_NAME})
set(EXECUTABLE_NAME ${APP_NAME})
set(MACOSX_BUNDLE_EXECUTABLE_NAME ${APP_NAME})
set(MACOSX_BUNDLE_INFO_STRING ${APP_BUNDLE_IDENTIFIER})
set(MACOSX_BUNDLE_GUI_IDENTIFIER ${APP_BUNDLE_IDENTIFIER})
set(MACOSX_BUNDLE_BUNDLE_NAME ${APP_BUNDLE_IDENTIFIER})
set(MACOSX_BUNDLE_ICON_FILE "")
set(MACOSX_BUNDLE_LONG_VERSION_STRING "1.0")
set(MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0")
set(MACOSX_BUNDLE_BUNDLE_VERSION "1.0")
set(MACOSX_BUNDLE_COPYRIGHT "Copyright YOU")
set(MACOSX_DEPLOYMENT_TARGET ${DEPLOYMENT_TARGET})

enable_language(Swift)

set(APP_SOURCE_FILES
	../MyApp/ContentView.swift
	../MyApp/MyAppApp.swift
)

add_executable(
	${APP_NAME}
	MACOSX_BUNDLE 
	${APP_SOURCE_FILES}
)

# Create the app target
set_target_properties(${APP_NAME} PROPERTIES
					  XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
					  XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/Prefix.pch"
					  RESOURCE "${RESOURCES}"
					  XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER "YES"
					  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET ${DEPLOYMENT_TARGET}
					  XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ${CODE_SIGN_IDENTITY}
					  XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ${DEVELOPMENT_TEAM_ID}
					  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY ${DEVICE_FAMILY}
					  #MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/plist.in
					  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
					  XCODE_ATTRIBUTE_COMBINE_HIDPI_IMAGES NO
					  XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
					  XCODE_ATTRIBUTE_ENABLE_TESTABILITY YES
					  XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN YES
					  XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos iphonesimulator"
					  XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD)"
					  XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
					  XCODE_ATTRIBUTE_CODE_SIGN_STYLE Manual
)






#set(TARGET_NAME "ExampleApp")


#enable_language(Swift)

# set target
#set(executable_name ${TARGET_NAME})

# set scheme
# set(CMAKE XCODE_GENERATE_SCHEME TRUE)


#set(executable_name "CMkakeApp.app")