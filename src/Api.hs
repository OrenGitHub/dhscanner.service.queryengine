module Api
    ( queryApi
    ) where

import Kbapi
import qualified WithComments
import ApiEnv (ApiEnv)
import qualified HttpHandlersApi
import qualified ControlFlowReachableSinksApi
import qualified ConstStringsApi
import qualified DataFlowPathApi
import qualified SanitizersApi

-- | Dispatch a Kbapi 'Query' to its handler module.
--
-- The agent's path for runner issue #105 : `SelectHttpHandlers` finds
-- the handlers and their user inputs, `SelectControlFlowReachableSinks`
-- the sinks a handler reaches, `SelectDataFlowPath` the flow from a user
-- input to a sink, and `SelectSanitizers` the `if` that guards it.
--
-- `SelectComments` has no handler yet and answers empty.
queryApi :: Query -> ApiEnv QueryResult
queryApi (SelectHttpHandlers q) = HttpHandlersApi.query q
queryApi (SelectControlFlowReachableSinks q) = ControlFlowReachableSinksApi.query q
queryApi (SelectConstStrings q) = ConstStringsApi.query q
queryApi (SelectDataFlowPath q) = DataFlowPathApi.query q
queryApi (SelectSanitizers q) = SanitizersApi.query q
queryApi (SelectComments _) = pure (FoundCommentsInFunction WithComments.Content { WithComments.total = 0, WithComments.matches = [] })
