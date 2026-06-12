// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "flutter_native_splash", path: "../.packages/flutter_native_splash-2.4.7"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "share_plus", path: "../.packages/share_plus-10.1.4"),
        .package(name: "sentry_flutter", path: "../.packages/sentry_flutter-9.19.0"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-8.3.1"),
        .package(name: "in_app_review", path: "../.packages/in_app_review-2.0.11"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.1"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-15.2.10"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-3.15.2"),
        .package(name: "audioplayers_darwin", path: "../.packages/audioplayers_darwin-6.4.0"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "flutter-native-splash", package: "flutter_native_splash"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "sentry-flutter", package: "sentry_flutter"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "in-app-review", package: "in_app_review"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "audioplayers-darwin", package: "audioplayers_darwin"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
