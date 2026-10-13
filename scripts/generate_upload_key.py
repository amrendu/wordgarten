#!/usr/bin/env python3
"""Prepare a private upload key for a first Play Store release; never replace it."""

import os
import pathlib
import secrets
import shutil
import subprocess
import sys


def main():
    root = pathlib.Path(__file__).resolve().parents[1]
    directory = root / 'android/signing'
    keystore = directory / 'wortgarten-upload.jks'
    properties = root / 'android/key.properties'
    certificate = directory / 'wortgarten-upload-certificate.pem'
    if keystore.exists() and properties.exists():
        print('Existing upload signing files preserved. No new key generated.')
        return
    if keystore.exists() or properties.exists():
        sys.exit('Incomplete signing setup. Restore the matching signing files; this script will not overwrite an existing key or configuration.')
    keytool = shutil.which('keytool')
    if not keytool:
        sys.exit('keytool was not found. Use the JDK bundled with Android Studio.')
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)
    password = secrets.token_urlsafe(36)
    environment = dict(os.environ, WORTGARTEN_UPLOAD_KEY_PASSWORD=password)
    generated = subprocess.run([
        keytool, '-genkeypair', '-keystore', str(keystore),
        '-storetype', 'PKCS12', '-alias', 'upload',
        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
        '-dname', 'CN=Wortgarten Upload',
        '-storepass:env', 'WORTGARTEN_UPLOAD_KEY_PASSWORD',
        '-keypass:env', 'WORTGARTEN_UPLOAD_KEY_PASSWORD',
    ], env=environment, capture_output=True, text=True)
    if generated.returncode:
        sys.exit('Upload key generation failed. Inspect the signing folder before retrying; no existing key will be replaced.')
    keystore.chmod(0o600)
    descriptor = os.open(properties, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as file:
        file.write(f'storePassword={password}\nkeyPassword={password}\nkeyAlias=upload\nstoreFile=signing/wortgarten-upload.jks\n')
    exported = subprocess.run([
        keytool, '-exportcert', '-rfc', '-keystore', str(keystore),
        '-alias', 'upload', '-file', str(certificate),
        '-storepass:env', 'WORTGARTEN_UPLOAD_KEY_PASSWORD',
    ], env=environment, capture_output=True, text=True)
    if exported.returncode:
        sys.exit('Upload key and private configuration created, but public certificate export failed.')
    print('Upload key and signing configuration created. Passwords were saved privately, not printed.')
    print('Back up android/signing/wortgarten-upload.jks and android/key.properties together.')
    print('Public upload certificate: android/signing/wortgarten-upload-certificate.pem')


if __name__ == '__main__':
    main()
