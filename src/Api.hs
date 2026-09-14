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

-- | Dispatch a Kbapi 'Query' to its handler module.
--
-- The four HTTP-handler queries (auth/unauth x GET/POST) are the "first
-- fork" surface for the LLM agent -- see docs/OWASP26_NOTES.md and the
-- talk's "first move" bridge slide. All four are wired explicitly; the
-- other Query constructors (CommentsInFunction, WriteContentToLocalFile,
-- ControlFlowPath, DataFlowPath) still fall through to the empty catch-all
-- because their handler modules haven't been added yet. When adding one,
-- replace the corresponding catch-all match with an explicit case.
queryApi :: Query -> ApiEnv QueryResult
queryApi (ConstStringsMatching q) = ConstStringsMatchingApi.query q
queryApi (HttpGetHandlerRequestObject q) = HttpGetHandlerRequestObjectApi.query q
queryApi (UnauthenticatedHttpGetHandlerRequestObject q) = UnauthenticatedHttpGetHandlerRequestObjectApi.query q
queryApi (AuthenticatedHttpGetHandlerRequestObject q) = AuthenticatedHttpGetHandlerRequestObjectApi.query q
queryApi (UnauthenticatedHttpPostHandlerRequestObject q) = UnauthenticatedHttpPostHandlerRequestObjectApi.query q
queryApi (AuthenticatedHttpPostHandlerRequestObject q) = AuthenticatedHttpPostHandlerRequestObjectApi.query q
queryApi _ = pure (FoundConstStringsMatching Content.FoundConstStringsMatching { Content.foundConstStringsMatchingThisRegex = "", Content.foundConstStringsMatchesTotal = 0, Content.foundConstStringsMatches = [] })
