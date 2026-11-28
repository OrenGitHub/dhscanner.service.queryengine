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
    , QueryFailed(..)
    , FailureKind(..)
    , requireAll
    , atomLocation
    , prologString
    , prologAtoms
    , prologQuotedAtom
    ) where

import qualified Location
import Kbgen (restoreloc)
import ApiEnv (ApiEnv, asksKbFilename, asksTimeoutSeconds)
import Swipl (saveAsMainFile, runSwiplWithTimeout, Stdout(..), Stderr(..), SwiplOutcome(..))
import Control.Exception (Exception, throwIO)
import Data.Aeson (FromJSON, decodeStrict)
import Data.Maybe (listToMaybe, mapMaybe)
import qualified Data.List as List
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Encoding as TE
import Control.Monad.IO.Class (liftIO)

-- | Fill @{KNOWLEDGE_BASE}@ plus the given slots into the template, run
-- it, and decode the last JSON line it prints. An empty answer is a reply
-- like any other ( @[]@, @null@ : "no path" ). A query that did not run,
-- or whose answer cannot be read, is never one : a timeout throws
-- 'QueryTimedOut' ( a 504 ), anything else 'QueryFailed' ( a 500 ).
runJsonTemplate :: FromJSON a => String -> FilePath -> [ (T.Text, String) ] -> ApiEnv a
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
        SwiplNotStarted -> failWith queryName PrologNotStarted "swipl could not be started"
        SwiplExited code (Stderr err) -> failWith queryName (exitKind code) err
        SwiplFinished (Stdout out) _ -> maybe (failWith queryName UndecodableReply (lastLines out)) pure (decodeOutput out)

-- | The query's swipl run hit the per-query time limit ( seconds ).
data QueryTimedOut = QueryTimedOut String Word deriving ( Show )

instance Exception QueryTimedOut

-- | The query did not run to an answer, or qe cannot read the answer : a
-- broken query, never an empty one. 'failedDetail' is what swipl printed
-- on stderr, or what could not be read.
data QueryFailed = QueryFailed
    { failedQuery :: String
    , failedKind :: FailureKind
    , failedDetail :: String
    }
    deriving ( Show )

instance Exception QueryFailed

data FailureKind
    = PrologFailed          -- ^ swipl exit 1 : `main` failed, or an error while loading
    | PrologException       -- ^ swipl exit 2 : an uncaught exception ( unknown procedure, stack limit )
    | PrologExited Int      -- ^ any other non-zero exit
    | PrologNotStarted
    | UndecodableReply      -- ^ no JSON line of the expected shape on stdout
    | UnreadableKbAtom      -- ^ a reply field qe cannot read back ( a location atom, a kind )
    deriving ( Show )

exitKind :: Int -> FailureKind
exitKind 1 = PrologFailed
exitKind 2 = PrologException
exitKind code = PrologExited code

failWith :: String -> FailureKind -> String -> ApiEnv a
failWith queryName kind detail = liftIO (throwIO (QueryFailed queryName kind detail))

-- | Every match of the reply, or 'QueryFailed' : a match qe cannot build
-- ( an unreadable location atom, an unknown kind ) is a bug, never one
-- match less.
requireAll :: Show a => String -> (a -> Maybe b) -> [ a ] -> ApiEnv [ b ]
requireAll queryName build = traverse build'
    where build' a = maybe (failWith queryName UnreadableKbAtom (take 2000 (show a))) pure (build a)

lastLines :: String -> String
lastLines = unlines . reverse . take 20 . reverse . lines

-- | The kb by its bare name : `[ '/tmp/kb_X' ]` loads `kb_X.qlf` when it
-- is not older than `kb_X.pl`, `[ '/tmp/kb_X.pl' ]` always the slow `.pl`
-- ( runner #246 ). Both spellings of the kb location are in use.
kbBareName :: String -> String
kbBareName kb = maybe kb reverse (List.stripPrefix (reverse ".pl") (reverse kb))

fillSlot :: T.Text -> (T.Text, String) -> T.Text
fillSlot template (slot, value) = T.replace slot (T.pack value) template

decodeOutput :: FromJSON a => String -> Maybe a
decodeOutput out = listToMaybe (mapMaybe decodeLine (reverse (lines out)))

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

-- | A Prolog single-quoted atom, its quotes, backslashes and control
-- characters escaped : the value comes from the client and must neither
-- end the atom early nor, through a newline, the comment line a template
-- slot may also sit in.
prologQuotedAtom :: String -> String
prologQuotedAtom s = "'" ++ concatMap escape s ++ "'"
    where
        escape '\'' = "\\'"
        escape '\\' = "\\\\"
        escape '\n' = "\\n"
        escape '\r' = "\\r"
        escape '\t' = "\\t"
        escape c | c < ' ' = ""
        escape c = [ c ]
