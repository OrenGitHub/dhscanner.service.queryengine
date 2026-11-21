module ApiEnv
    ( ApiConfig(..)
    , ApiEnv
    , runApiEnv
    , asksKbFilename
    , asksTimeoutSeconds
    ) where

import Control.Monad.Reader (ReaderT, asks, runReaderT)

data ApiConfig
    = ApiConfig
    {
        apiEnvKbFilename :: FilePath
        -- | the per-query swipl time limit ( `?timeout_seconds=` )
    ,   apiEnvTimeoutSeconds :: Word
    }

type ApiEnv = ReaderT ApiConfig IO

runApiEnv :: ApiConfig -> ApiEnv a -> IO a
runApiEnv = flip runReaderT

asksKbFilename :: ApiEnv FilePath
asksKbFilename = asks apiEnvKbFilename

asksTimeoutSeconds :: ApiEnv Word
asksTimeoutSeconds = asks apiEnvTimeoutSeconds
