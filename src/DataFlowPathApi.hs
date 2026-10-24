{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectDataFlowPath` kbapi query : the shortest
-- intra-procedural dataflow path between two locations ( falling back to
-- one inter-procedural hop when allowed ), as the list of locations it
-- visits.
module DataFlowPathApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Kbgen (locationify)
import qualified WithDataFlowPath as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Control.Monad (join)

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "DataFlowPath" "templates/templateDataFlowPath.pl"
        [ ("{FROM_ATOM}", locationify (Q.from features))
        , ("{TO_ATOM}", locationify (Q.to features))
        , ("{LIMIT_LENGTH}", show (Q.maxNumIntraProceduralEdges features))
        , ("{ALLOW_INTER_PROCEDURAL}", allowInterProcedural (Q.maxNumInterProceduralEdges features))
        ]
    pure (FoundDataFlowPath Q.Content
        { Q.path = join reply >>= traverse atomLocation
        })

allowInterProcedural :: Word -> String
allowInterProcedural 0 = "fail"
allowInterProcedural _ = "true"
