{-# LANGUAGE OverloadedStrings #-}

-- | Shared runner for query templates whose `main/0` prints its answer as
-- a single JSON document ( `library(http/json)` ), so handlers decode the
-- reply with aeson instead of hand-parsing Prolog terms.
--
-- Location atoms travel as JSON strings and come back through
-- `Kbgen.restoreloc`.
module JsonTemplate
    ( runJsonTemplate
    , QueryTimedOut(..)
    , atomLocation
    , prologString
    , prologAtoms
    ) where

import qualified Location
import Kbgen (restoreloc)
import ApiEnv (ApiEnv, asksKbFilename, asksTimeoutSeconds)
import Swipl (saveAsMainFile, runSwiplWithTimeout, Stdout(..), SwiplOutcome(..))
import Control.Exception (Exception, throwIO)
import Data.Aeson (FromJSON, decodeStrict)
import Data.Maybe (listToMaybe, mapMaybe)
import qualified Data.List as List
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Encoding as TE
import Control.Monad.IO.Class (liftIO)

-- | Fill @{KNOWLEDGE_BASE}@ plus the given slots into the template, run
-- it, and decode the last JSON line it prints. 'Nothing' on a Prolog
-- error ( non-zero exit ) or an undecodable reply. A timeout throws
-- 'QueryTimedOut' : it must reach the client as an error ( a 504 ), never
-- as an empty answer ( "no path", "0 sinks" ).
runJsonTemplate :: FromJSON a => String -> FilePath -> [ (T.Text, String) ] -> ApiEnv (Maybe a)
runJsonTemplate queryName templatePath slots = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] " ++ queryName ++ " using kb: " ++ kbFilename))
    template <- liftIO (TIO.readFile templatePath)
    let program = List.foldl' fillSlot template (("{KNOWLEDGE_BASE}", kbBareName kbFilename) : slots)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    seconds <- asksTimeoutSeconds
    outcome <- liftIO (runSwiplWithTimeout seconds path)
    case outcome of
        SwiplTimedOut -> liftIO (throwIO (QueryTimedOut queryName seconds))
        SwiplFinished output -> pure (decodeOutput output)

-- | The query's swipl run hit the per-query time limit ( seconds ).
data QueryTimedOut = QueryTimedOut String Word deriving ( Show )

instance Exception QueryTimedOut

-- | The kb by its bare name : `[ '/tmp/kb_X' ]` loads `kb_X.qlf` when it
-- is not older than `kb_X.pl`, `[ '/tmp/kb_X.pl' ]` always the slow `.pl`
-- ( runner #246 ). Both spellings of the kb location are in use.
kbBareName :: String -> String
kbBareName kb = maybe kb reverse (List.stripPrefix (reverse ".pl") (reverse kb))

fillSlot :: T.Text -> (T.Text, String) -> T.Text
fillSlot template (slot, value) = T.replace slot (T.pack value) template

decodeOutput :: FromJSON a => Maybe (Stdout, b) -> Maybe a
decodeOutput (Just (Stdout out, _)) = listToMaybe (mapMaybe decodeLine (reverse (lines out)))
decodeOutput _ = Nothing

decodeLine :: FromJSON a => String -> Maybe a
decodeLine = decodeStrict . TE.encodeUtf8 . T.pack

atomLocation :: String -> Maybe Location.Location
atomLocation = restoreloc

-- | A Prolog double-quoted string literal.
prologString :: String -> String
prologString s = "\"" ++ concatMap escape s ++ "\""
    where
        escape '"' = "\\\""
        escape '\\' = "\\\\"
        escape c = [ c ]

-- | A Prolog list of quoted atoms.
prologAtoms :: [ String ] -> String
prologAtoms atoms = "[" ++ List.intercalate ", " (map (\a -> "'" ++ a ++ "'") atoms) ++ "]"
