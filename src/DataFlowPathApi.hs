{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `DataFlowPath` kbapi query : the shortest
-- intra-procedural dataflow path between two locations ( falling back to
-- one inter-procedural hop ), as the list of locations it visits.
module DataFlowPathApi
    ( query
    ) where

import qualified Content
import Kbapi (QueryResult(..))
import Kbgen (locationify)
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Control.Monad (join)

query :: Content.DataFlowPath -> ApiEnv QueryResult
query (Content.DataFlowPath from to limitLength) = do
    reply <- runJsonTemplate "DataFlowPath" "templates/templateDataFlowPath.pl"
        [ ("{FROM_ATOM}", locationify from)
        , ("{TO_ATOM}", locationify to)
        , ("{LIMIT_LENGTH}", show limitLength)
        ]
    pure (FoundDataFlowPath Content.FoundDataFlowPath
        { Content.foundDataFlowPathPath = join reply >>= traverse atomLocation
        })
