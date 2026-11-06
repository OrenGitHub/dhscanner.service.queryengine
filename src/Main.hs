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
import Logging
import KbWriter ( writeFactsStreamToTempFile )
import GHC.Generics
import qualified Data.Text as T
import Network.Wai.Handler.Warp (run)
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
    query <- requireCheckJsonBody :: Handler Query
    let apiConfig = ApiConfig { apiEnvKbFilename = kbFilename }
    result <- liftIO (runApiEnv apiConfig (queryApi query))
    $logInfo "API query finished"
    returnJson result

requireKbFilename :: Handler String
requireKbFilename = do
    kbFilename <- lookupGetParam "kb_location"
    case kbFilename of
        Just path -> pure (T.unpack path)
        Nothing -> invalidArgs [ "missing query parameter: kb_location" ]

main :: IO ()
main = do
    waiApp <- toWaiAppPlain App
    run 3000 $ defaultMiddlewaresNoLogging waiApp
