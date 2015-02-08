{-# LANGUAGE ForeignFunctionInterface, CPP, MultiParamTypeClasses #-}

-- |
-- Module      : Crypto.Hash.Internal.SHA512
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unknown
--
-- A module containing SHA512 bindings
--
module Crypto.Hash.Internal.SHA512
    ( Ctx(..)
    -- * Internal values
    , digestSize
    , sizeCtx
    -- * Internal IO hash functions
    , internalInit
    , internalInitAt
    , internalUpdate
    , internalFinalize
    -- * Context copy and creation
    , withCtxNew
    , withCtxCopy
    , withCtxNewThrow
    , withCtxThrow
    ) where

import Foreign.Ptr
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.Storable
import Foreign.Marshal.Alloc
import Data.ByteString (ByteString)
import Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import Data.ByteString.Internal (create, toForeignPtr)
import Data.Word

newtype Ctx = Ctx ByteString

{-# INLINE digestSize #-}
digestSize :: Int
digestSize = 64

{-# INLINE sizeCtx #-}
sizeCtx :: Int
sizeCtx = 256

{-# INLINE withByteStringPtr #-}
withByteStringPtr :: ByteString -> (Ptr Word8 -> IO a) -> IO a
withByteStringPtr b f =
    withForeignPtr fptr $ \ptr -> f (ptr `plusPtr` off)
    where (fptr, off, _) = toForeignPtr b

{-# INLINE memcopy64 #-}
memcopy64 :: Ptr Word64 -> Ptr Word64 -> IO ()
memcopy64 dst src = mapM_ peekAndPoke [0..(32-1)]
    where peekAndPoke i = peekElemOff src i >>= pokeElemOff dst i

withCtxCopy :: Ctx -> (Ptr Ctx -> IO ()) -> IO Ctx
withCtxCopy (Ctx ctxB) f = Ctx `fmap` createCtx
    where createCtx = create sizeCtx $ \dstPtr ->
                      withByteStringPtr ctxB $ \srcPtr -> do
                          memcopy64 (castPtr dstPtr) (castPtr srcPtr)
                          f (castPtr dstPtr)

withCtxThrow :: Ctx -> (Ptr Ctx -> IO a) -> IO a
withCtxThrow (Ctx ctxB) f =
    allocaBytes sizeCtx $ \dstPtr ->
    withByteStringPtr ctxB $ \srcPtr -> do
        memcopy64 (castPtr dstPtr) (castPtr srcPtr)
        f (castPtr dstPtr)

withCtxNew :: (Ptr Ctx -> IO ()) -> IO Ctx
withCtxNew f = Ctx `fmap` create sizeCtx (f . castPtr)

withCtxNewThrow :: (Ptr Ctx -> IO a) -> IO a
withCtxNewThrow f = allocaBytes sizeCtx (f . castPtr)

foreign import ccall unsafe "cryptonite_sha512.h cryptonite_sha512_init"
    c_sha512_init :: Ptr Ctx -> IO ()

foreign import ccall "cryptonite_sha512.h cryptonite_sha512_update"
    c_sha512_update :: Ptr Ctx -> Ptr Word8 -> Word32 -> IO ()

foreign import ccall unsafe "cryptonite_sha512.h cryptonite_sha512_finalize"
    c_sha512_finalize :: Ptr Ctx -> Ptr Word8 -> IO ()

internalInitAt :: Ptr Ctx -> IO ()
internalInitAt = c_sha512_init

-- | init a context
internalInit :: IO Ctx
internalInit = withCtxNew internalInitAt

-- | Update a context in place
internalUpdate :: Ptr Ctx -> ByteString -> IO ()
internalUpdate ptr d =
    unsafeUseAsCStringLen d (\(cs, len) -> c_sha512_update ptr (castPtr cs) (fromIntegral len))

-- | Finalize a context in place
internalFinalize :: Ptr Ctx -> IO ByteString
internalFinalize ptr = create digestSize (c_sha512_finalize ptr)
