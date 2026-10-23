{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `BranchGuardedCall` kbapi query : every `if` whose
-- then- or else-branch holds the queried call ( `kb_gated_call/3` ),
-- with the condition's resolved fqn and the calls ( + their const string
-- args ) on the other branch.
module BranchGuardedCallApi
    ( query
    ) where

import qualified Content
import Kbapi (QueryResult(..))
import Kbgen (locationify)
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Data.Aeson (FromJSON(..), withObject, (.:), (.:?))
import Data.Maybe (fromMaybe, mapMaybe)

data Guard = Guard String (Maybe String) [ Call ]

data Call = Call String (Maybe String) [ String ]

instance FromJSON Guard where
    parseJSON = withObject "Guard" (\o -> Guard
        <$> o .: "conditionLocation"
        <*> o .:? "conditionQualifiedName"
        <*> o .: "otherBranchCalls")

instance FromJSON Call where
    parseJSON = withObject "Call" (\o -> Call
        <$> o .: "location"
        <*> o .:? "qualifiedName"
        <*> o .: "constStringArgs")

query :: Content.BranchGuardedCall -> ApiEnv QueryResult
query (Content.BranchGuardedCall call limit) = do
    reply <- runJsonTemplate "BranchGuardedCall" "templates/templateBranchGuardedCall.pl"
        [ ("{CALL_ATOM}", locationify call)
        , ("{LIMIT}", show limit)
        ]
    let guards = mapMaybe buildGuard (fromMaybe [] reply)
    pure (FoundBranchGuardedCall Content.FoundBranchGuardedCall
        { Content.foundBranchGuardedCallTotal = fromIntegral (length guards)
        , Content.foundBranchGuardedCallGuards = guards
        })

buildGuard :: Guard -> Maybe Content.BranchGuard
buildGuard (Guard atom fqn calls) = do
    loc <- atomLocation atom
    pure Content.BranchGuard
        { Content.branchGuardConditionLocation = loc
        , Content.branchGuardConditionQualifiedName = fqn
        , Content.branchGuardOtherBranchCalls = mapMaybe buildCall calls
        }

buildCall :: Call -> Maybe Content.BranchCall
buildCall (Call atom fqn strings) = do
    loc <- atomLocation atom
    pure Content.BranchCall
        { Content.branchCallLocation = loc
        , Content.branchCallQualifiedName = fqn
        , Content.branchCallConstStringArgs = strings
        }
