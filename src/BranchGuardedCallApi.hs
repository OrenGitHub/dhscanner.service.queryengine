{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `BranchGuardedCall` kbapi query : every `if` that
-- guards the queried call against the user input with the if-then-else
-- sanitizer gadget ( `sanitizers_branch_guard/3` in
-- `predicates/sanitizers/api.pl` ) : the condition is a call, the user
-- input flows into one of its args, one branch holds the queried call and
-- the other branch holds an error call.
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

data Guard = Guard String String Word [ Step ] [ Call ] [ Call ]

data Step = Step String (Maybe String)

data Call = Call String (Maybe String) [ String ]

instance FromJSON Guard where
    parseJSON = withObject "Guard" (\o -> Guard
        <$> o .: "conditionLocation"
        <*> o .: "conditionQualifiedName"
        <*> o .: "userInputArgIndex"
        <*> o .: "userInputFlow"
        <*> o .: "errorCalls"
        <*> o .: "otherBranchCalls")

instance FromJSON Step where
    parseJSON = withObject "Step" (\o -> Step
        <$> o .: "location"
        <*> o .:? "qualifiedName")

instance FromJSON Call where
    parseJSON = withObject "Call" (\o -> Call
        <$> o .: "location"
        <*> o .:? "qualifiedName"
        <*> o .: "constStringArgs")

query :: Content.BranchGuardedCall -> ApiEnv QueryResult
query (Content.BranchGuardedCall call userInput limit) = do
    reply <- runJsonTemplate "BranchGuardedCall" "templates/templateBranchGuardedCall.pl"
        [ ("{CALL_ATOM}", locationify call)
        , ("{USER_INPUT_ATOM}", locationify userInput)
        , ("{LIMIT}", show limit)
        ]
    let guards = mapMaybe buildGuard (fromMaybe [] reply)
    pure (FoundBranchGuardedCall Content.FoundBranchGuardedCall
        { Content.foundBranchGuardedCallTotal = fromIntegral (length guards)
        , Content.foundBranchGuardedCallGuards = guards
        })

buildGuard :: Guard -> Maybe Content.BranchGuard
buildGuard (Guard atom fqn argIndex steps errors others) = do
    loc <- atomLocation atom
    flow <- traverse buildStep steps
    pure Content.BranchGuard
        { Content.branchGuardConditionLocation = loc
        , Content.branchGuardConditionQualifiedName = fqn
        , Content.branchGuardUserInputArgIndex = argIndex
        , Content.branchGuardUserInputFlow = flow
        , Content.branchGuardErrorCalls = mapMaybe buildCall errors
        , Content.branchGuardOtherBranchCalls = mapMaybe buildCall others
        }

buildStep :: Step -> Maybe Content.FlowStep
buildStep (Step atom fqn) = do
    loc <- atomLocation atom
    pure Content.FlowStep
        { Content.flowStepLocation = loc
        , Content.flowStepQualifiedName = fqn
        }

buildCall :: Call -> Maybe Content.BranchCall
buildCall (Call atom fqn strings) = do
    loc <- atomLocation atom
    pure Content.BranchCall
        { Content.branchCallLocation = loc
        , Content.branchCallQualifiedName = fqn
        , Content.branchCallConstStringArgs = strings
        }
