#!/usr/bin/python
import os
import M2Crypto

SIGNER_KEY = M2Crypto.RSA.gen_key (1024, 65537)
SIGNER_KEY.save_key ('signer_key.pem', None)
SIGNER_KEY.save_pub_key ('signer_key_pub.pem')