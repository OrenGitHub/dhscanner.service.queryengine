{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectControlFlowReachableSinks` kbapi query : every
-- call site within a bounded number of hops from the source callable
-- whose sink kind is one of the requested ones
-- ( `templates/templateControlFlowReachableSinks.pl` ).
module ControlFlowReachableSinksApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Kbgen (locationify)
import qualified WithControlFlowReachableSinks as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation, prologAtoms)
import Data.Aeson (FromJSON(..), withObject, (.:))
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.Set as Set

data Match = Match String String Q.Sink

instance FromJSON Match where
    parseJSON = withObject "Match" (\o -> Match <$> o .: "location" <*> o .: "qualifiedName" <*> o .: "kind")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "ControlFlowReachableSinks" "templates/templateControlFlowReachableSinks.pl"
        [ ("{SOURCE_ATOM}", locationify (Q.from features))
        , ("{LIMIT_NUM_HOPS}", show (Q.maxNumHops features))
        , ("{SINKS}", prologAtoms (map show (Set.toList (Q.sinks features))))
        , ("{LIMIT}", show (Q.maxNumSinks features))
        ]
    let matches = mapMaybe buildMatch (fromMaybe [] reply)
    pure (FoundControlFlowReachableSinks Q.Content
        { Q.total = fromIntegral (length matches)
        , Q.matches = matches
        })

buildMatch :: Match -> Maybe Q.Match
buildMatch (Match atom fqn kind) = do
    loc <- atomLocation atom
    pure Q.Match
        { Q.location = loc
        , Q.qualifiedName = fqn
        , Q.kind = kind
        }
