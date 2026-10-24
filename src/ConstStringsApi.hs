{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectConstStrings` kbapi query : const strings
-- matching a regex ( `templates/templateConstStrings.pl` ).
module ConstStringsApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import qualified WithConstStrings as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation, prologString)
import Data.Aeson (FromJSON(..), withObject, (.:))
import Data.Maybe (fromMaybe, mapMaybe)

data Match = Match String String

instance FromJSON Match where
    parseJSON = withObject "Match" (\o -> Match <$> o .: "location" <*> o .: "value")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "ConstStrings" "templates/templateConstStrings.pl"
        [ ("{REGEX}", prologString (Q.matchingRegex features))
        , ("{LIMIT}", show (Q.maxNumConstStrings features))
        ]
    let matches = mapMaybe buildMatch (fromMaybe [] reply)
    pure (FoundConstStringsMatching Q.Content
        { Q.total = fromIntegral (length matches)
        , Q.matches = matches
        })

buildMatch :: Match -> Maybe Q.Match
buildMatch (Match atom value) = do
    loc <- atomLocation atom
    pure Q.Match
        { Q.location = loc
        , Q.value = value
        }
