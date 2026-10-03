package com.techkushx.fixitfelix

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: Google Sign-In presents its
// account picker as a DialogFragment and needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
