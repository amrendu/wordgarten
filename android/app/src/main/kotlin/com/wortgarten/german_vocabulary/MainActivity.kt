package com.wortgarten.german_vocabulary

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Do not let the system's exit animation obscure the Flutter garden.
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
    }
}
