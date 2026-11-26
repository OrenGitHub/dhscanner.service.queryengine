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
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation)
import Data.Aeson (FromJSON(..), withObject, (.:), (.:?))
import Control.Monad (join)

-- | The template's reply : the path atoms, plus the model and the column
-- of a db write the path stores into
data Reply = Reply [ String ] (Maybe String) (Maybe String)

instance FromJSON Reply where
    parseJSON = withObject "Reply" (\o -> Reply <$> o .: "path" <*> o .:? "model" <*> o .:? "column")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "DataFlowPath" "templates/templateDataFlowPath.pl"
        [ ("{FROM_ATOM}", locationify (Q.from features))
        , ("{TO_ATOM}", locationify (Q.to features))
        , ("{LIMIT_LENGTH}", show (Q.maxNumIntraProceduralEdges features))
        , ("{ALLOW_INTER_PROCEDURAL}", allowInterProcedural (Q.maxNumInterProceduralEdges features))
        ]
    pure (FoundDataFlowPath (content (join reply)))

content :: Maybe Reply -> Q.Content
content (Just (Reply atoms model column)) = case (traverse atomLocation atoms, model, column) of
    (Just path, Just m, Just c) -> Q.DbWriteDataFlowPath (Q.DBWriteDataFlowContent (Q.Model m) (Q.Column c) path)
    (Just path, _, _) -> Q.PlainDataFlowPath (Q.PlainDataFlowContent path)
    (Nothing, _, _) -> Q.NoDataFlowPath
content Nothing = Q.NoDataFlowPath

allowInterProcedural :: Word -> String
allowInterProcedural 0 = "fail"
allowInterProcedural _ = "true"
