{-# LANGUAGE OverloadedStrings #-}

-- | The kb file, written from a stream of facts ( the `/uploadkb` body ).
--
-- The body is a json array of kbgen facts. It is parsed one element at a
-- time ( json-stream ), each element decoded by `FromJSON Fact` and
-- rendered by `prologify` right away, so memory does not grow with the
-- body. Decoding the whole body as `[ Fact ]` took ~9 GB for Discourse's
-- 1.6M facts ( 541 MB of json, runner, 2026-11-06 ).
--
-- The kb lines are sorted, so the clauses of each predicate are together.
-- The sort is GNU `sort` ( external, bounded memory ). A fact can span
-- lines ( a multi line string constant ), so the unsorted file has one
-- NUL terminated record per fact ( `sort -z` ), and the NULs become
-- newlines after the sort. With `LC_ALL=C` the order is the byte order,
-- which for utf-8 is the code point order of the former `List.sort` on
-- `String`s : the kb is byte for byte the same as before.
module KbWriter
    ( writeFactsStreamToTempFile
    , factsFromJsonArray
    ) where

import Kbgen ( Fact, prologify )
import Data.Conduit ( ConduitT, runConduit, (.|), fuseBoth, yield, await )
import qualified Data.Conduit.Combinators as C
import Data.JsonStream.Parser ( Parser, ParseOutput(..), runParser, arrayOf, value )
import qualified Data.Aeson as AE
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BB
import Control.Monad.IO.Class ( MonadIO, liftIO )
import System.Directory ( getTemporaryDirectory, removeFile )
import System.Exit ( ExitCode(..) )
import System.IO ( openTempFile, hClose, hSetBinaryMode, hSetBuffering, BufferMode(..) )
import System.Process ( proc, readCreateProcessWithExitCode, CreateProcess(..) )

-- | The elements of a json array, as facts. The result is `Left` with the
-- parser's message when the body is not a json array of facts ( an element
-- failing `FromJSON Fact`, invalid json, a truncated body ). The facts
-- yielded before the failure are already downstream : the caller decides
-- what to keep.
--
-- Each element is parsed as an aeson `Value` and converted here : with
-- `value :: Parser Fact`, json-stream silently skips an element whose
-- `FromJSON` fails.
factsFromJsonArray :: Monad m => ConduitT BS.ByteString Fact m (Either String ())
factsFromJsonArray = go (runParser elements)
    where
        elements = arrayOf value :: Parser AE.Value
        go (ParseYield element next) = case AE.fromJSON element of
            AE.Success fact -> yield fact >> go next
            AE.Error err -> pure (Left ("not a kbgen fact : " ++ err))
        go (ParseNeedData more) = await >>= maybe (pure (Left "incomplete json body")) (go . more)
        go (ParseFailed err) = pure (Left err)
        go (ParseDone _) = pure (Right ())

-- | The sorted kb file of a stream of facts, and the number of facts.
-- `Left` : the body is not a json array of facts, or the sort failed. No
-- file is left behind then : a kb is returned only when every fact decoded.
writeFactsStreamToTempFile :: MonadIO m => ConduitT () BS.ByteString m () -> m (Either String (FilePath, Int))
writeFactsStreamToTempFile body = do
    tmpDir <- liftIO getTemporaryDirectory
    (unsortedPath, unsorted) <- liftIO (openTempFile tmpDir "kb_unsorted_XXXXXXXX.pl")
    liftIO (hSetBinaryMode unsorted True >> hSetBuffering unsorted (BlockBuffering (Just 1048576)))
    (parsed, numFacts) <- runConduit (body .| fuseBoth factsFromJsonArray (C.foldM (writeRecord unsorted) 0))
    liftIO (hClose unsorted)
    case parsed of
        Left err -> do
            liftIO (removeFile unsortedPath)
            pure (Left err)
        Right () -> liftIO $ do
            sorted <- sortRecords tmpDir unsortedPath
            removeFile unsortedPath
            pure (fmap (\kbPath -> (kbPath, numFacts)) sorted)
    where
        writeRecord h n fact = do
            liftIO (BB.hPutBuilder h (BB.stringUtf8 (prologify fact) <> BB.word8 0))
            pure $! n + 1

-- | `sort -z` the NUL terminated records into a new kb file, NULs -> newlines.
sortRecords :: FilePath -> FilePath -> IO (Either String FilePath)
sortRecords tmpDir unsortedPath = do
    (kbPath, kb) <- openTempFile tmpDir "kb_XXXXXXXX.pl"
    hClose kb
    let script = "LC_ALL=C sort -z -S 1G -T \"$1\" --parallel=4 \"$2\" | tr '\\0' '\\n' > \"$3\""
    (code, _, err) <- readCreateProcessWithExitCode
        (proc "/bin/bash" [ "-o", "pipefail", "-c", script, "sort", tmpDir, unsortedPath, kbPath ])
        { env = Just [ ("PATH", "/usr/bin:/bin") ] }
        ""
    case code of
        ExitSuccess -> pure (Right kbPath)
        ExitFailure c -> do
            removeFile kbPath
            pure (Left ("sort failed ( exit " ++ show c ++ " ) : " ++ err))
