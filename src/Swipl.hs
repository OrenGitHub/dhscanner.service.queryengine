{-# LANGUAGE OverloadedStrings  #-}

module Swipl
    ( Stdout(..)
    , Stderr(..)
    , runSwiplWithTimeout
    , saveAsMainFile
    ) where

import System.Timeout (timeout)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (getTemporaryDirectory)
import System.Process ( proc, createProcess, waitForProcess, ProcessHandle, CreateProcess(..), StdStream(..), terminateProcess )
import System.Exit ( ExitCode(..) )
import Control.Concurrent ( forkIO, threadDelay, killThread, ThreadId )
import Control.Concurrent.MVar ( newEmptyMVar, putMVar, takeMVar )
import Control.Exception ( finally, evaluate )
import Control.Monad ( join )
import System.IO ( Handle, openTempFile, hClose, hGetContents, hSetEncoding, utf8 )
import qualified System.IO as IO

newtype Stdout = Stdout String deriving ( Show, Eq )
newtype Stderr = Stderr String deriving ( Show, Eq )

saveAsMainFile :: T.Text -> IO FilePath
saveAsMainFile content = do
    tmpDir <- getTemporaryDirectory
    (path, handle) <- openTempFile tmpDir "main_XXXXXXXX.pl"
    IO.hPutStrLn IO.stderr ("[queryengine][swipl] generated main prolog file: " ++ path)
    writeMainFileHandle content path handle

writeMainFileHandle :: T.Text -> FilePath -> Handle -> IO FilePath
writeMainFileHandle content path handle = do
    hSetEncoding handle utf8
    TIO.hPutStr handle content
    hClose handle
    pure path

-- 3 minutes timeout
swiplTimeLimitSeconds :: Word
swiplTimeLimitSeconds = 180

-- convert to signed + microseconds for actual OS execution
swiplTimeLimitMicroseconds :: Int
swiplTimeLimitMicroseconds = fromIntegral (swiplTimeLimitSeconds * 1000000)

swiplArgs :: FilePath -> [ String ]
swiplArgs path = ["--quiet", "-s", path, "-g", "main", "-t", "halt"]

swiplProcessConfig :: FilePath -> CreateProcess
swiplProcessConfig path = (proc "swipl" (swiplArgs path)) {
    std_out = CreatePipe,
    std_err = CreatePipe,
    create_group = True
}

createSwiplProcess :: FilePath -> IO (Maybe (Handle, Handle, ProcessHandle))
createSwiplProcess path = do
    (_, mOut, mErr, ph) <- createProcess (swiplProcessConfig path)
    pure (case (mOut, mErr) of { (Just out, Just err) -> Just (out, err, ph); _ -> Nothing })

killSwiplProcess :: ProcessHandle -> IO ()
killSwiplProcess ph = do { terminateProcess ph; threadDelay 1000000; terminateProcess ph }

setupTimeoutKiller :: ProcessHandle -> IO ThreadId
setupTimeoutKiller ph = forkIO (do { threadDelay swiplTimeLimitMicroseconds; killSwiplProcess ph })

readProcessOutput' :: ExitCode -> String -> String -> Maybe (Stdout, Stderr)
readProcessOutput' ExitSuccess out err = Just (Stdout out, Stderr err)
readProcessOutput' _ _ _ = Nothing

-- | drain both pipes /before/ waiting for swipl : an output larger than
-- the pipe buffer ( ~64KB, eg every handler of a big repo ) otherwise
-- blocks swipl on its write while we block on its exit, until the
-- timeout kills it. stderr drains on its own thread so neither pipe
-- can fill up while the other one is read.
readProcessOutput :: Handle -> Handle -> ProcessHandle -> IO (Maybe (Stdout, Stderr))
readProcessOutput hOut hErr ph = do
    errVar <- newEmptyMVar
    _ <- forkIO (drain hErr >>= putMVar errVar)
    out' <- drain hOut
    err' <- takeMVar errVar
    exitCode <- waitForProcess ph
    pure (readProcessOutput' exitCode out' err')

drain :: Handle -> IO String
drain h = do
    content <- hGetContents h
    evaluate (length content `seq` content)

runProcessWithTimeout :: Handle -> Handle -> ProcessHandle -> IO (Maybe (Stdout, Stderr))
runProcessWithTimeout hOut hErr ph = do
    timeoutThread <- setupTimeoutKiller ph
    let processAction = readProcessOutput hOut hErr ph
    mResult <- timeout swiplTimeLimitMicroseconds processAction `finally` killThread timeoutThread
    pure (join mResult)

runSwiplWithTimeout' :: Maybe (Handle, Handle, ProcessHandle) -> IO (Maybe (Stdout, Stderr))
runSwiplWithTimeout' (Just (hOut, hErr, ph)) = runProcessWithTimeout hOut hErr ph
runSwiplWithTimeout' _ = pure Nothing

runSwiplWithTimeout :: FilePath -> IO (Maybe (Stdout, Stderr))
runSwiplWithTimeout path = createSwiplProcess path >>= runSwiplWithTimeout'
