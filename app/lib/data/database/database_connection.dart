import 'package:drift/drift.dart';

import 'database_connection_impl_io.dart'
    if (dart.library.js_interop) 'database_connection_impl_web.dart' as impl;

QueryExecutor openConnection() => impl.openConnection();
