{-# LANGUAGE OverloadedStrings  #-}

module Swipl
    ( Stdout(..)
    , Stderr(..)
    , SwiplOutcome(..)
    , defaultTimeLimitSeconds
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
import System.IO ( Handle, openTempFile, hClose, hGetContents, hSetEncoding, utf8 )
import qualified System.IO as IO

newtype Stdout = Stdout String deriving ( Show, Eq )
newtype Stderr = Stderr String deriving ( Show, Eq )

-- | A run that hit the time limit is NOT a run without an answer : the
-- caller must not read it as "no path" / "0 sinks" ( runner, 2026-11-21 :
-- six 180 s timeouts read as "no flow" made a file upload handler `safe` ).
data SwiplOutcome
    = SwiplFinished (Maybe (Stdout, Stderr)) -- ^ 'Nothing' : non-zero exit
    | SwiplTimedOut
    deriving ( Show, Eq )

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

-- | Per query, when the request names none ( `?timeout_seconds=` ).
-- Measured on a 1.2k-file Java repo ( 589 queries ) : every dataflow path
-- found took <= 1.7 s, the slow ones ( 10 .. 180 s ) were all "no path";
-- the endpoints seed ~39 s alone, more than 45 s with 10 in parallel, so
-- the client asks for more on that one.
defaultTimeLimitSeconds :: Word
defaultTimeLimitSeconds = 45

-- convert to signed + microseconds for actual OS execution
toMicroseconds :: Word -> Int
toMicroseconds seconds = fromIntegral (seconds * 1000000)

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

setupTimeoutKiller :: Word -> ProcessHandle -> IO ThreadId
setupTimeoutKiller seconds ph = forkIO (do { threadDelay (toMicroseconds seconds); killSwiplProcess ph })

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

runProcessWithTimeout :: Word -> Handle -> Handle -> ProcessHandle -> IO SwiplOutcome
runProcessWithTimeout seconds hOut hErr ph = do
    timeoutThread <- setupTimeoutKiller seconds ph
    let processAction = readProcessOutput hOut hErr ph
    mResult <- timeout (toMicroseconds seconds) processAction `finally` killThread timeoutThread
    pure (maybe SwiplTimedOut SwiplFinished mResult)

runSwiplWithTimeout' :: Word -> Maybe (Handle, Handle, ProcessHandle) -> IO SwiplOutcome
runSwiplWithTimeout' seconds (Just (hOut, hErr, ph)) = runProcessWithTimeout seconds hOut hErr ph
runSwiplWithTimeout' _ _ = pure (SwiplFinished Nothing)

-- | Run the main file, killed after the given number of seconds.
runSwiplWithTimeout :: Word -> FilePath -> IO SwiplOutcome
runSwiplWithTimeout seconds path = createSwiplProcess path >>= runSwiplWithTimeout' seconds
