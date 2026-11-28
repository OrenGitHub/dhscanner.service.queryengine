{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectDataFlowPath` kbapi query : the shortest
-- intra-procedural dataflow path between two locations ( falling back to
-- one inter-procedural hop when allowed ), as the list of locations it
-- visits. When the target writes to a db and the path goes through the
-- value it stores, the reply also names the model and the column.
module DataFlowPathApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Kbgen (locationify)
import qualified WithDataFlowPath as Q
import qualified Common
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation, QueryFailed(..), FailureKind(..))
import Data.Aeson (FromJSON(..), withObject, (.:), (.:?))
import Control.Exception (throwIO)
import Control.Monad.IO.Class (liftIO)

-- | The template's reply : the path atoms, plus the model and the column
-- of a db write the path stores into
data Reply = Reply [ String ] (Maybe String) (Maybe String) deriving ( Show )

instance FromJSON Reply where
    parseJSON = withObject "Reply" (\o -> Reply <$> o .: "path" <*> o .:? "model" <*> o .:? "column")

-- | The intra procedural edge limit is at least this : a shorter one silently
-- answers "no path" for real flows ( a stored value read, rendered by a
-- template that includes another one, then written to and read from a
-- global is 13 edges ), and the search stays fast well past it.
minNumIntraProceduralEdges :: Word
minNumIntraProceduralEdges = 20

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "DataFlowPath" "templates/templateDataFlowPath.pl"
        [ ("{FROM_ATOM}", locationify (Q.from features))
        , ("{TO_ATOM}", locationify (Q.to features))
        , ("{LIMIT_LENGTH}", show (max minNumIntraProceduralEdges (Q.maxNumIntraProceduralEdges features)))
        , ("{ALLOW_INTER_PROCEDURAL}", allowInterProcedural (Q.maxNumInterProceduralEdges features))
        ]
    -- `null` : no path, an answer ; a path qe cannot read back : a failure
    case reply of
        Nothing -> pure (FoundDataFlowPath Q.NoDataFlowPath)
        Just r -> maybe (liftIO (throwIO (QueryFailed "DataFlowPath" UnreadableKbAtom (show r)))) (pure . FoundDataFlowPath) (content r)

content :: Reply -> Maybe Q.Content
content (Reply atoms model column) = do
    path <- traverse atomLocation atoms
    pure (case (model, column) of
        (Just m, Just c) -> Q.DBWriteDataFlowPath (Q.DBWriteDataFlowContent (Common.Model m) (Common.Column c) path)
        _ -> Q.PlainDataFlowPath (Q.PlainDataFlowContent path))

allowInterProcedural :: Word -> String
allowInterProcedural 0 = "fail"
allowInterProcedural _ = "true"
