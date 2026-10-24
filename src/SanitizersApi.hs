{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectSanitizers` kbapi query : every top level
-- if-then-else whose then or else part holds the sink and whose
-- condition is a call the user input flows into
-- ( `templates/templateSanitizers.pl` ).
module SanitizersApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Kbgen (locationify)
import qualified WithSanitizers as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Data.Aeson (FromJSON(..), withObject, (.:), (.:?))
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.List as List

data Gadget = Gadget Call Word [ Step ] [ Call ] [ Call ]

data Step = Step String (Maybe String)

data Call = Call String (Maybe String) [ String ]

instance FromJSON Gadget where
    parseJSON = withObject "Gadget" (\o -> Gadget
        <$> o .: "cond"
        <*> o .: "userInputArgIndex"
        <*> o .: "userInputFlow"
        <*> o .: "thenPart"
        <*> o .: "elsePart")

instance FromJSON Step where
    parseJSON = withObject "Step" (\o -> Step <$> o .: "location" <*> o .:? "qualifiedName")

instance FromJSON Call where
    parseJSON = withObject "Call" (\o -> Call <$> o .: "location" <*> o .:? "qualifiedName" <*> o .: "constStringArgs")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "Sanitizers" "templates/templateSanitizers.pl"
        [ ("{SINK_ATOM}", locationify (Q.sink features))
        , ("{USER_INPUT_ATOM}", locationify (Q.userInput features))
        , ("{LIMIT}", show (Q.maxNumSanitizers features))
        ]
    let matches = mapMaybe buildGadget (fromMaybe [] reply)
    pure (FoundSanitizers Q.Content
        { Q.total = fromIntegral (length matches)
        , Q.matches = matches
        })

buildGadget :: Gadget -> Maybe Q.Sanitizer
buildGadget (Gadget cond argIndex steps thenPart elsePart) = do
    cond' <- buildCall cond
    flow <- traverse buildStep steps
    pure (Q.TopLevelIfThenElse Q.IfThenElse
        { Q.cond = cond'
        , Q.userInputArgIndex = argIndex
        , Q.userInputFlow = flow
        , Q.thenPart = buildPart thenPart
        , Q.elsePart = buildPart elsePart
        })

buildPart :: [ Call ] -> [ Q.PartCall ]
buildPart = List.sortOn Q.location . mapMaybe buildCall

buildStep :: Step -> Maybe Q.FlowStep
buildStep (Step atom fqn) = do
    loc <- atomLocation atom
    pure Q.FlowStep
        { Q.flowStepLocation = loc
        , Q.flowStepQualifiedName = fqn
        }

buildCall :: Call -> Maybe Q.PartCall
buildCall (Call atom fqn strings) = do
    loc <- atomLocation atom
    pure Q.PartCall
        { Q.location = loc
        , Q.qualifiedName = fqn
        , Q.constStringArgs = strings
        }
