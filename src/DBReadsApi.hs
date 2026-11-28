{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectDBReads` kbapi query : the reads of a column of
-- a 1st party model that an endpoint reaches, each with the call sites
-- from the endpoint down to it ( `templates/templateDBReads.pl` ).
module DBReadsApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Kbgen (locationify)
import qualified Common
import qualified WithDBReads as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation, prologQuotedAtom, requireAll)
import Data.Aeson (FromJSON(..), withObject, (.:))

data Match = Match String [ String ] deriving ( Show )

instance FromJSON Match where
    parseJSON = withObject "Match" (\o -> Match <$> o .: "dbRead" <*> o .: "endpointToDBRead")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    let Common.Model model = Q.model features
    let Common.Column column = Q.column features
    reply <- runJsonTemplate "DBReads" "templates/templateDBReads.pl"
        [ ("{ENDPOINT_ATOM}", locationify (Q.endpoint features))
        , ("{MODEL}", prologQuotedAtom model)
        , ("{COLUMN}", prologQuotedAtom column)
        , ("{LIMIT_NUM_HOPS}", show (Q.maxNumInterProceduralHops features))
        , ("{LIMIT}", show (Q.maxNumMatches features))
        ]
    matches <- requireAll "DBReads" buildMatch reply
    pure (FoundDBReads Q.Content
        { Q.total = fromIntegral (length matches)
        , Q.matches = matches
        })

buildMatch :: Match -> Maybe Q.Match
buildMatch (Match readAtom chainAtoms) = do
    loc <- atomLocation readAtom
    chain <- traverse atomLocation chainAtoms
    pure Q.Match
        { Q.dbRead = Q.DBRead loc
        , Q.endpointToDBRead = chain
        }
