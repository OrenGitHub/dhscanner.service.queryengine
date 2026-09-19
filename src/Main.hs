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
-- logging, all of which live in yesod-core.
import Yesod.Core
import Data.Aeson ( ToJSON(..), Value, object, (.=) )
import Kbgen
import Kbapi ( Query )
import Api ( queryApi )
import ApiEnv ( ApiConfig(..), runApiEnv )
import Logging
import Swipl
import GHC.Generics
import Data.List as List
import qualified Data.Text as T
import qualified Network.Wai
import qualified Network.HTTP.Types.Status as NetworkHTTPTypes
import Network.Wai.Handler.Warp (run)
import Data.Word ( Word64 )

newtype Healthy = Healthy Bool deriving ( Generic )

instance ToJSON Healthy where toJSON (Healthy status) = object [ "healthy" .= status ]

data App = App

mkYesod "App" [parseRoutes|
/querycheck QuerycheckR POST
/uploadkb UploadkbR POST
/api ApiR POST
/healthcheck HealthcheckR GET
|]

-- 256MB. Bumped from 64MB because phpBB's fact set for /uploadkb
-- exceeded the old limit, causing the Yesod-level 413 that silently
-- fell through in workers/queryengine/main.py's run_with_agent_mode.
-- 256MB is a straight 4x quick-fix; the "right" answer is a shared-
-- volume handoff so /uploadkb takes a path instead of a body, but
-- that's a bigger refactor and this unblocks the OWASP demo work.
useIncreasedSizeLimit :: Word64
useIncreasedSizeLimit = 256000000

instance Yesod App where
    maximumContentLength _thereIsOnly1AppHere (Just QuerycheckR) = Just useIncreasedSizeLimit
    maximumContentLength _thereIsOnly1AppHere (Just UploadkbR) = Just useIncreasedSizeLimit
    maximumContentLength _thereIsOnly1AppHere (Just ApiR) = Just useIncreasedSizeLimit
    maximumContentLength _thereIsOnly1AppHere _ = Nothing
    makeLogger _thereIsOnly1AppHere = customizedLogger
    messageLoggerSource _thereIsOnly1AppHere = messageLoggerWithoutSource

getHealthcheckR :: Handler Value
getHealthcheckR = returnJson (Healthy True)

logFactsInfo :: [ Kbgen.Fact ] -> Handler ()
logFactsInfo facts = do
    $logInfo $ T.pack ("Num facts received: " ++ show (length facts))

postQuerycheckR :: Handler Value
postQuerycheckR = do
    facts <- requireCheckJsonBody :: Handler [ Kbgen.Fact ]
    logFactsInfo facts
    results <- liftIO (queryEngine facts)
    postQuerycheck' results

postUploadkbR :: Handler Value
postUploadkbR = do
    facts <- requireCheckJsonBody :: Handler [ Kbgen.Fact ]
    logFactsInfo facts
    kb_filename <- liftIO (writeFactsToTempFile facts)
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

newtype Timeout = Timeout Bool deriving ( Show, Eq )

receivedTimeout :: QueryEngineResult -> Timeout
receivedTimeout = Timeout . receivedTimeout'

receivedTimeout' :: QueryEngineResult -> Bool
receivedTimeout' result = null (Swipl.stdout result) && "timeout:" `List.isPrefixOf` Swipl.stderr result

postQuerycheck' :: QueryEngineResult -> Handler Value
postQuerycheck' results = postQuerycheck'' (receivedTimeout results) results

postQuerycheck'' :: Timeout -> QueryEngineResult -> Handler Value
postQuerycheck'' (Timeout True) _ = returnGatewayTimeout504
postQuerycheck'' (Timeout False) results = returnJson results

returnGatewayTimeout504 :: Handler Value
returnGatewayTimeout504 = returnBodylessHttpStatusCode NetworkHTTPTypes.gatewayTimeout504

returnBodylessHttpStatusCode :: NetworkHTTPTypes.Status -> Handler Value
returnBodylessHttpStatusCode status = sendWaiResponse (Network.Wai.responseBuilder status [] mempty)

main :: IO ()
main = do
    waiApp <- toWaiAppPlain App
    run 3000 $ defaultMiddlewaresNoLogging waiApp
