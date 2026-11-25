{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# LANGUAGE TypeFamilies      #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}

{-# OPTIONS -Wno-unused-matches   #-}
{-# OPTIONS -Wno-unused-top-binds #-}

-- Depend on yesod-core directly rather than the `yesod` metapackage :
-- the metapackage transitively pulls in yesod-persistent and, from
-- there, the deprecated persistent-template ( now shipped on Hackage
-- with an empty exposed-modules list, which cabal treats as an
-- unbuildable library and refuses to solve ). The queryengine has
-- never used forms or DB persistence -- only routing, TH sugar,
-- logging, all of which live in yesod-core. Yesod.Core re-exports
-- ToJSON / Value / object / .= from aeson, so no separate aeson
-- import is needed here.
import Yesod.Core
import Kbapi ( Query )
import Api ( queryApi )
import ApiEnv ( ApiConfig(..), runApiEnv )
import JsonTemplate ( QueryTimedOut(..) )
import Swipl ( defaultTimeLimitSeconds )
import Control.Exception ( try )
import Network.HTTP.Types.Status ( gatewayTimeout504, notFound404 )
import System.Directory ( doesFileExist, getTemporaryDirectory )
import System.FilePath ( isAbsolute, (</>) )
import Control.Monad ( unless )
import Logging
import KbWriter ( writeFactsStreamToTempFile )
import GHC.Generics
import qualified Data.Text as T
import Network.Wai.Handler.Warp ( runSettings, setPort, setTimeout, defaultSettings )
import Data.Word ( Word64 )

newtype Healthy = Healthy Bool deriving ( Generic )

instance ToJSON Healthy where toJSON (Healthy status) = object [ "healthy" .= status ]

data App = App

mkYesod "App" [parseRoutes|
/uploadkb UploadkbR POST
/api ApiR POST
/healthcheck HealthcheckR GET
|]

-- 2GB. Bumped from 64MB because phpBB's fact set for /uploadkb
-- exceeded the old limit, causing the Yesod-level 413 that silently
-- fell through in workers/queryengine/main.py's run_with_agent_mode,
-- then from 256MB because full DSpace's fact set is ~344MB, then from
-- 512MB because Discourse's is ~541MB once ruby block bodies are kept.
-- The "right" answer is a shared-volume handoff so /uploadkb takes a
-- path instead of a body, but that's a bigger refactor.
useIncreasedSizeLimit :: Word64
useIncreasedSizeLimit = 2000000000

instance Yesod App where
    maximumContentLength _thereIsOnly1AppHere (Just UploadkbR) = Just useIncreasedSizeLimit
    maximumContentLength _thereIsOnly1AppHere (Just ApiR) = Just useIncreasedSizeLimit
    maximumContentLength _thereIsOnly1AppHere _ = Nothing
    makeLogger _thereIsOnly1AppHere = customizedLogger
    messageLoggerSource _thereIsOnly1AppHere = messageLoggerWithoutSource

getHealthcheckR :: Handler Value
getHealthcheckR = returnJson (Healthy True)

-- | The body is a json array of kbgen facts, streamed : each fact is
-- decoded and written as it arrives ( `KbWriter` ). A body that is not a
-- json array of facts is a 400, and no kb is written.
postUploadkbR :: Handler Value
postUploadkbR = do
    written <- writeFactsStreamToTempFile rawRequestBody
    case written of
        Left err -> invalidArgs [ T.pack err ]
        Right (kb_filename, numFacts) -> do
            $logInfo $ T.pack ("Num facts received: " ++ show numFacts)
            $logInfo $ T.pack ("KB written to: " ++ kb_filename)
            returnJson $ object [ "kb_location" .= kb_filename ]

postApiR :: Handler Value
postApiR = do
    kbFilename <- requireKbFilename
    $logInfo $ T.pack ("API query request for kb: " ++ kbFilename)
    requireExistingKb kbFilename
    seconds <- requireTimeoutSeconds
    query <- requireCheckJsonBody :: Handler Query
    let apiConfig = ApiConfig { apiEnvKbFilename = kbFilename, apiEnvTimeoutSeconds = seconds }
    result <- liftIO (try (runApiEnv apiConfig (queryApi query)))
    case result of
        Left (QueryTimedOut queryName limit) -> do
            let msg = queryName ++ " timed out after " ++ show limit ++ " s ( no answer, NOT an empty answer )"
            $logWarn (T.pack ("API query " ++ msg))
            sendResponseStatus gatewayTimeout504 (object [ "error" .= msg ])
        Right reply -> do
            $logInfo "API query finished"
            returnJson reply

-- | A query on a kb that is not there is a 404, not an empty answer :
-- swipl fails to load it, and the reply read "no path" ( HTTP 200 ). The
-- templates live in the temp dir, so a relative kb name is relative to it.
requireExistingKb :: String -> Handler ()
requireExistingKb kb = do
    tmpDir <- liftIO getTemporaryDirectory
    let path = if isAbsolute kb then kb else tmpDir </> kb
    found <- liftIO (or <$> mapM doesFileExist [ path, path ++ ".pl", path ++ ".qlf" ])
    unless found (sendResponseStatus notFound404 (object [ "error" .= ("kb not found: " ++ kb) ]))

-- | `?timeout_seconds=N` : the client's per-query bound ( 1 .. 600 ),
-- 45 s when absent ( Swipl.defaultTimeLimitSeconds ).
requireTimeoutSeconds :: Handler Word
requireTimeoutSeconds = do
    raw <- lookupGetParam "timeout_seconds"
    case raw of
        Nothing -> pure defaultTimeLimitSeconds
        Just txt -> case reads (T.unpack txt) :: [ (Integer, String) ] of
            [ (n, "") ] | n >= 1 && n <= 600 -> pure (fromIntegral n)
            _ -> invalidArgs [ "timeout_seconds must be an integer in 1 .. 600, got: " <> txt ]

requireKbFilename :: Handler String
requireKbFilename = do
    kbFilename <- lookupGetParam "kb_location"
    case kbFilename of
        Just path -> pure (T.unpack path)
        Nothing -> invalidArgs [ "missing query parameter: kb_location" ]

main :: IO ()
main = do
    waiApp <- toWaiAppPlain App
    -- 60 s : /uploadkb sorts and qlf compiles the kb without I/O, 35 s for
    -- Discourse ( Warp's default 30 s closed the connection mid compile )
    runSettings (setPort 3000 (setTimeout 60 defaultSettings)) $ defaultMiddlewaresNoLogging waiApp
