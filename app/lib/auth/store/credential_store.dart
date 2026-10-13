export 'credential_store_base.dart';

import 'credential_store_base.dart';
import 'credential_store_io.dart'
    if (dart.library.js_interop) 'credential_store_web.dart' as impl;

CredentialStore createCredentialStore() => impl.createCredentialStore();
