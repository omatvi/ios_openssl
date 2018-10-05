# ios_openssl
Current script provide easy to use solution to build Openssl library for iOS/OSx platform.

Simple steps to execute:
1. Download or clone repository
2. Open terminal *cd /your_folder_name/* where build_openssl.sh stored
    1. Optional: *chmod +x build_openssl.sh*
3. *./build_openssl.sh*
4. Done (check created folders: include, lib)

**Xcode integration**

Copy your folder into Xcode project directory

**Target Build Settings**

Under your target’s **Build Settings** edit **LIBRARY_SEARCH_PATHS** to include: *$(PROJECT_DIR)/your_folder_name/lib*.

Set **HEADER_SEARCH_PATHS** to include: *$(SRCROOT)/your_folder_name/include*.

**ModuleMap**

Now create a Swift ModuleMap in order to let the compiler know what C files  should be associated with a custom module.

1. Create a shim.h file. This is an import header file which imports all OpenSSL files you need to expose (you can get list of all headers from *include* folder).

```c

// A shim header to bridge C to a Swift modulemap

#ifndef __OPENSSL_SHIM_H__
#define __OPENSSL_SHIM_H__

#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/md4.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include <openssl/ripemd.h>
#include <openssl/pkcs12.h>
#include <openssl/x509v3.h>

#endif
```
2. Create a custom module.modulemap

```c
/// Expose OpenSSL for extraneous Swift usage
module OpenSSL {
    header "shim.h"
}
```
3. In target’s **Build Settings** edit **IMPORT_PATHS** to include: 
   
   *\$(SRCROOT)/$(TARGET_NAME)* . This tells the compiler to look into project folder for custom module maps.

4. *import OpenSSL* into your swift class

**Usage example**

``` swift
//
//  RSAKeypair.swift
//
//  Created by Oleksandr Matviishyn on 8/2/18.
//  Copyright © 2018 Oleksandr Matviishyn. All rights reserved.
//

import Foundation
import OpenSSL

class RSAKeypair {
    
    private let KEY_LENGTH: Int32 = 2048
    private var publicKey: String?
    private var privateKey: String?
    
     // Generate key pair
     func generateKeypair() {
        print("Generating RSA (%d bits) keypair...", KEY_LENGTH)
        
        let error = BN_new()
        BN_set_word(error, 65537)

        // KeyPair
        let rsaKeyPair = RSA_new()
        RSA_generate_key_ex(rsaKeyPair, KEY_LENGTH, error, nil)
        BN_free(error);
        let pubBio = BIO_new(BIO_s_mem());
        let pubKey = PEM_write_bio_RSAPublicKey(pubBio, rsaKeyPair)
        let pubBioKeylen = BIO_ctrl(pubBio,BIO_CTRL_PENDING,0,nil)// BIO_pending(bio);
        
        let priBio = BIO_new(BIO_s_mem())
        let priKey = PEM_write_bio_RSAPrivateKey(priBio, rsaKeyPair, nil, nil, 0, nil, nil)
        let priBioKeylen = BIO_ctrl(priBio,BIO_CTRL_PENDING,0,nil)// BIO_pending(bio);

        var pubBuffer = [CChar](repeating: 0, count: pubBioKeylen)
        BIO_read(pubBio, &pubBuffer, Int32(pubBuffer.count))
        publicKey = String(cString: pubBuffer)
        print(publicKey)
        
        var priBuffer = [CChar](repeating: 0, count: priBioKeylen)
        BIO_read(priBio, &priBuffer, Int32(priBuffer.count))
        privateKey = String(cString: priBuffer)
        print(privateKey)
    }
```
