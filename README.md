# Google Messages for iPad

A native SwiftUI iPad shell for Google Messages for web. Messages, pairing, search, compose, attachments, and conversation actions stay in Google's own web client; this app adds iPad navigation, a persistent app-local web session, touch-friendly controls, page zoom, and iPadOS background refresh scheduling.

## Pairing and sign-in
Open the app and choose **Continue to Google Messages**. The Google page handles its normal sign-in and device-pairing flow. To pair with a phone, use Google Messages' QR pairing screen and scan it from the phone's Messages app. Keep the phone powered and connected to the internet for linked-device service.

The WKWebView uses its persistent website data store inside this app. Its cookies and site data are separate from Safari and other browsers. The app does not read, copy, or export message contents.

## Background behavior
iPadOS suspends apps in the background and schedules refresh work at its discretion. This app requests an occasional background availability check, then refreshes the Messages web page when the app returns to the foreground. It cannot promise continuous live message sync while suspended; Google controls linked-device connectivity and the phone must remain online.

## Build locally
1. Install Xcode and XcodeGen.
2. From the repository root run `xcodegen generate`.
3. Open `GoogleMessages.xcodeproj` in Xcode, select the GoogleMessages scheme, and build for an iPad simulator or device.
4. For sideloading, archive/export with signing disabled or use the **Build unsigned iPad IPA** GitHub Action.

## GitHub Actions
Pushes to the default branch and manual runs start a runner race across compatible macOS/Xcode runners. The first runner to atomically claim the build wins; its workflow cancels the other runner workflows and builds an unsigned arm64 iPad IPA. The parent workflow publishes the IPA as a downloadable Actions artifact named `Google-Messages-unsigned-IPA`.

In GitHub, open **Actions → Build unsigned iPad IPA → latest run → Artifacts**. Download the artifact and pass the IPA to Sideloadly. The app is unsigned and must be signed with your Apple ID before installation.

## Notes
- Google may change or restrict Messages for web at any time. Authentication, pairing, and messaging availability depend on Google's web client and account.
- App Store distribution requires signing and review; this workflow intentionally creates an unsigned sideloading build.
