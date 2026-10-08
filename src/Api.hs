module Api
    ( queryApi
    ) where

import Kbapi
import qualified Content
import ApiEnv (ApiEnv)
import qualified ConstStringsMatchingApi
import qualified HttpGetHandlerRequestObjectApi
import qualified UnauthenticatedHttpGetHandlerRequestObjectApi
import qualified AuthenticatedHttpGetHandlerRequestObjectApi
import qualified UnauthenticatedHttpPostHandlerRequestObjectApi
import qualified AuthenticatedHttpPostHandlerRequestObjectApi
import qualified UnauthenticatedHttpPutHandlerRequestObjectApi
import qualified AuthenticatedHttpPutHandlerRequestObjectApi
import qualified ControlFlowReachableSqlSinkApi

-- | Dispatch a Kbapi 'Query' to its handler module.
--
-- The six HTTP-handler queries (auth/unauth x GET/POST/PUT) are the
-- "first fork" surface for the LLM agent -- see docs/OWASP26_NOTES.md
-- and the talk's "first move" bridge slide. `ControlFlowReachableSqlSink`
-- is the second-move "where does this handler land in the DB layer?"
-- query -- see `utils_control_flow_reaches_sink_fqn/2` in `utils.pl` for
-- the three-edge bounded-closure design that answers it.
--
-- The remaining Query constructors (CommentsInFunction,
-- WriteContentToLocalFile, ControlFlowPath, DataFlowPath,
-- ControlFlowReachableFileActionSink) still fall through to the empty
-- catch-all because their handler modules haven't been added yet. When
-- adding one, replace the corresponding catch-all match with an
-- explicit case.
queryApi :: Query -> ApiEnv QueryResult
queryApi (ConstStringsMatching q) = ConstStringsMatchingApi.query q
queryApi (HttpGetHandlerRequestObject q) = HttpGetHandlerRequestObjectApi.query q
queryApi (UnauthenticatedHttpGetHandlerRequestObject q) = UnauthenticatedHttpGetHandlerRequestObjectApi.query q
queryApi (AuthenticatedHttpGetHandlerRequestObject q) = AuthenticatedHttpGetHandlerRequestObjectApi.query q
queryApi (UnauthenticatedHttpPostHandlerRequestObject q) = UnauthenticatedHttpPostHandlerRequestObjectApi.query q
queryApi (AuthenticatedHttpPostHandlerRequestObject q) = AuthenticatedHttpPostHandlerRequestObjectApi.query q
queryApi (UnauthenticatedHttpPutHandlerRequestObject q) = UnauthenticatedHttpPutHandlerRequestObjectApi.query q
queryApi (AuthenticatedHttpPutHandlerRequestObject q) = AuthenticatedHttpPutHandlerRequestObjectApi.query q
queryApi (ControlFlowReachableSqlSink q) = ControlFlowReachableSqlSinkApi.query q
queryApi _ = pure (FoundConstStringsMatching Content.FoundConstStringsMatching { Content.foundConstStringsMatchingThisRegex = "", Content.foundConstStringsMatchesTotal = 0, Content.foundConstStringsMatches = [] })
