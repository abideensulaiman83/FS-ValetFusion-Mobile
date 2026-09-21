package com.focalsoft.fsvalet.fs_valetfusion;

import io.flutter.embedding.android.FlutterFragmentActivity;

// local_auth's BiometricPrompt requires a FragmentActivity host - plain FlutterActivity doesn't
// have the fragment manager it needs, and the biometric prompt silently fails to show without this.
public class MainActivity extends FlutterFragmentActivity {
}
