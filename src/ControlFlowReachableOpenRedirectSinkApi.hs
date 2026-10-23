{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `ControlFlowReachableOpenRedirectSink` kbapi query.
--
-- Same bounded control-flow closure as `ControlFlowReachableSqlSinkApi`,
-- but each match carries the sink call site ( not the source handler ),
-- so it can feed `DataFlowPath` / `BranchGuardedCall` directly. Sink
-- membership is `sinks_open_redirect/1` ( `predicates/sinks/api.pl` ).
module ControlFlowReachableOpenRedirectSinkApi
    ( query
    ) where

import qualified Content
import Kbapi (QueryResult(..))
import Kbgen (locationify)
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Data.Aeson (FromJSON(..), withObject, (.:))
import Data.Maybe (fromMaybe, mapMaybe)

data Match = Match String String

instance FromJSON Match where
    parseJSON = withObject "Match" (\o -> Match <$> o .: "location" <*> o .: "qualifiedName")

query :: Content.ControlFlowReachableOpenRedirectSink -> ApiEnv QueryResult
query (Content.ControlFlowReachableOpenRedirectSink from numHops limit) = do
    reply <- runJsonTemplate "ControlFlowReachableOpenRedirectSink" "templates/templateControlFlowReachableOpenRedirectSink.pl"
        [ ("{SOURCE_ATOM}", locationify from)
        , ("{LIMIT_NUM_HOPS}", show numHops)
        , ("{LIMIT}", show limit)
        ]
    let matches = mapMaybe buildMatch (fromMaybe [] reply)
    pure (FoundControlFlowReachableOpenRedirectSink Content.FoundControlFlowReachableOpenRedirectSink
        { Content.foundControlFlowReachableOpenRedirectSinkTotal = fromIntegral (length matches)
        , Content.foundControlFlowReachableOpenRedirectSinkMatches = matches
        })

buildMatch :: Match -> Maybe Content.FoundControlFlowReachableOpenRedirectSinkMatch
buildMatch (Match atom fqn) = do
    loc <- atomLocation atom
    pure Content.FoundControlFlowReachableOpenRedirectSinkMatch
        { Content.foundControlFlowReachableOpenRedirectSinkMatchLocation = loc
        , Content.foundControlFlowReachableOpenRedirectSinkMatchQualifiedName = fqn
        }
