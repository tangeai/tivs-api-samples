# Flutter API Samples

SDK `1.8.0-alpha.14` from hosted source `https://tangeai.github.io/tivs-sdk-flutter-hosted`. The complete package contains its native dependencies.

Build the macOS application:

```sh
flutter pub get
flutter build macos
```

Configure your own app ID/package with RAPID_APP_ID/RAPID_PACKAGE_NAME Dart defines and enter your account/device in the App. All six platform scaffolds are retained. Release admission builds and loads only the macOS arm64 App; the other targets retain SDK payload validation. Android uses locally generated debug signing; OHOS signing must be configured locally in DevEco Studio.

Build the isolated package loader with:

```sh
flutter build macos --target lib/sdk_load_probe.dart \
  --dart-define=RAPID_EXPECTED_VERSION=1.8.0-alpha.14
```

Run the executable in the generated App. It verifies the native version and Core/Media/SDL FFI exports. Git dependencies are supported in customer applications; pub.dev packages cannot declare Git dependencies.
