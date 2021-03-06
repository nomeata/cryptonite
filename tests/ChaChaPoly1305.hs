{-# LANGUAGE OverloadedStrings #-}
module ChaChaPoly1305 where

import qualified Crypto.Cipher.ChaChaPoly1305 as AEAD
import Imports
import Crypto.Error
import Poly1305 ()

import qualified Data.ByteString as B
import qualified Data.ByteArray as B (convert)

plaintext, aad, key, iv, ciphertext, tag :: B.ByteString
plaintext = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
aad = "\x50\x51\x52\x53\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7"
key = "\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f"
iv = "\x40\x41\x42\x43\x44\x45\x46\x47"
constant = "\x07\x00\x00\x00"
ciphertext = "\xd3\x1a\x8d\x34\x64\x8e\x60\xdb\x7b\x86\xaf\xbc\x53\xef\x7e\xc2\xa4\xad\xed\x51\x29\x6e\x08\xfe\xa9\xe2\xb5\xa7\x36\xee\x62\xd6\x3d\xbe\xa4\x5e\x8c\xa9\x67\x12\x82\xfa\xfb\x69\xda\x92\x72\x8b\x1a\x71\xde\x0a\x9e\x06\x0b\x29\x05\xd6\xa5\xb6\x7e\xcd\x3b\x36\x92\xdd\xbd\x7f\x2d\x77\x8b\x8c\x98\x03\xae\xe3\x28\x09\x1b\x58\xfa\xb3\x24\xe4\xfa\xd6\x75\x94\x55\x85\x80\x8b\x48\x31\xd7\xbc\x3f\xf4\xde\xf0\x8e\x4b\x7a\x9d\xe5\x76\xd2\x65\x86\xce\xc6\x4b\x61\x16"
tag = "\x1a\xe1\x0b\x59\x4f\x09\xe2\x6a\x7e\x90\x2e\xcb\xd0\x60\x06\x91"

tests = testGroup "ChaChaPoly1305"
    [ testCase "V1" runEncrypt
    , testCase "V1-decrypt" runDecrypt
    ]
  where runEncrypt =
            let ini                 = throwCryptoError $ AEAD.initialize key (throwCryptoError $ AEAD.nonce8 constant iv)
                afterAAD            = AEAD.finalizeAAD (AEAD.appendAAD aad ini)
                (out, afterEncrypt) = AEAD.encrypt plaintext afterAAD
                outtag              = AEAD.finalize afterEncrypt
             in propertyHoldCase [ eqTest "ciphertext" ciphertext out
                                 , eqTest "tag" tag (B.convert outtag)
                                 ]

        runDecrypt =
            let ini                 = throwCryptoError $ AEAD.initialize key (throwCryptoError $ AEAD.nonce8 constant iv)
                afterAAD            = AEAD.finalizeAAD (AEAD.appendAAD aad ini)
                (out, afterDecrypt) = AEAD.decrypt ciphertext afterAAD
                outtag              = AEAD.finalize afterDecrypt
             in propertyHoldCase [ eqTest "plaintext" plaintext out
                                 , eqTest "tag" tag (B.convert outtag)
                                 ]
