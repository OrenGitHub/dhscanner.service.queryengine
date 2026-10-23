{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `HandlerUserInputs` kbapi query : the params of a
-- handler that `endpoints_user_input/1` recognizes as user input
-- ( eg spring `@RequestParam` params ), in param order.
module HandlerUserInputsApi
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
    parseJSON = withObject "Match" (\o -> Match <$> o .: "location" <*> o .: "name")

query :: Content.HandlerUserInputs -> ApiEnv QueryResult
query (Content.HandlerUserInputs handler limit) = do
    reply <- runJsonTemplate "HandlerUserInputs" "templates/templateHandlerUserInputs.pl"
        [ ("{HANDLER_ATOM}", locationify handler)
        , ("{LIMIT}", show limit)
        ]
    let matches = mapMaybe buildMatch (fromMaybe [] reply)
    pure (FoundHandlerUserInputs Content.FoundHandlerUserInputs
        { Content.foundHandlerUserInputsTotal = fromIntegral (length matches)
        , Content.foundHandlerUserInputsMatches = matches
        })

buildMatch :: Match -> Maybe Content.FoundHandlerUserInput
buildMatch (Match atom name) = do
    loc <- atomLocation atom
    pure Content.FoundHandlerUserInput
        { Content.foundHandlerUserInputLocation = loc
        , Content.foundHandlerUserInputName = name
        }
