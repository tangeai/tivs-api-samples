import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        print('TGLAB_DRIVER_REPORT ${jsonEncode(data)}');
      },
    );
