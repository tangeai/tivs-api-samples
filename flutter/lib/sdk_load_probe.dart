import 'dart:ffi';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:rapid_kit/rapid_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final library = DynamicLibrary.process();
  for (final symbol in ['RAPID_Core_VersionName', 'RAPID_MediaPlayer_Create', 'RAPID_SDL_Aout_Silence_Create']) {
    library.lookup<Void>(symbol);
  }
  const expected = String.fromEnvironment('RAPID_EXPECTED_VERSION');
  const expectedCommit = String.fromEnvironment('RAPID_EXPECTED_COMMIT');
  if (expected.isEmpty || RapidKit.versionName != expected ||
      (expectedCommit.isNotEmpty && RapidKit.commitHash != expectedCommit)) exit(1);
  stdout.writeln('RAPID_SAMPLE_LOADED version=${RapidKit.versionName} commit=${RapidKit.commitHash}');
  exit(0);
}
