{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `ControlFlowReachableSqlSink` kbapi query.
--
-- Instantiates `templates/templateControlFlowReachableSqlSink.pl` with the
-- caller-supplied source `Location` ( encoded via `Kbgen.locationify`,
-- same atom key `kb_func_def/4` uses ) + hop / match budgets, invokes
-- swipl, decodes the `Fqn(...)` output lines, and shapes a
-- `FoundControlFlowReachableSqlSink` reply.
--
-- SQL-sink membership is decided Prolog-side ( substring probe on
-- `.prisma.` ; extensible per-family in the template ) ; the structural
-- `SqlRaw` vs `SqlPreparedStatement` split is decided here on the
-- returned FQN tail. First-cut classification table :
--
--   `.$queryRaw` / `.$queryRawUnsafe` / `.$executeRaw`
--   `.$executeRawUnsafe` / `.$transaction`      -> `SqlRaw`
--
--   everything else ( typesafe model methods )  -> `SqlPreparedStatement`
--
-- Per-match `Location` is the input source handler itself for now ;
-- surfacing the sink call site is a follow-up refinement that will
-- plumb `CallSite` through a sibling closure predicate in `utils.pl`.
module ControlFlowReachableSqlSinkApi
    ( query
    ) where

import qualified Content
import qualified Location
import Kbapi (QueryResult(..))
import Kbgen (locationify)
import ApiEnv (ApiEnv, asksKbFilename)
import Swipl (saveAsMainFile, runSwiplWithTimeout, Stdout(..))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Maybe (mapMaybe)
import Data.Char (isSpace)
import Data.List (isSuffixOf, stripPrefix, dropWhileEnd)
import Control.Monad.IO.Class (liftIO)

query :: Content.ControlFlowReachableSqlSink -> ApiEnv QueryResult
query (Content.ControlFlowReachableSqlSink from numHops limit) = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] ControlFlowReachableSqlSink using kb: " ++ kbFilename))
    let sourceAtom = locationify from
    liftIO (putStrLn ("[queryengine][api] source atom: " ++ sourceAtom))
    program <- liftIO (instantiateTemplate kbFilename sourceAtom numHops limit)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    outputOrTimeout <- liftIO (runSwiplWithTimeout path)
    let fqns = decodeFqns outputOrTimeout
    let matches = map (buildMatch from) fqns
    let total = fromIntegral (length matches)
    pure (FoundControlFlowReachableSqlSink Content.FoundControlFlowReachableSqlSink
        { Content.foundControlFlowReachableSqlSinkTotal = total
        , Content.foundControlFlowReachableSqlSinkCountsByKind = countsByKind matches
        , Content.foundControlFlowReachableSqlSinkMatches = matches
        })

-- | Shape one reached FQN into a `FoundControlFlowReachableSqlSinkMatch`.
-- Location is the source handler for the first cut ; sink-call-site
-- locations are a follow-up refinement.
buildMatch :: Location.Location -> String
           -> Content.FoundControlFlowReachableSqlSinkMatch
buildMatch handlerLoc fqn = Content.FoundControlFlowReachableSqlSinkMatch
    { Content.foundControlFlowReachableSqlSinkMatchLocation = handlerLoc
    , Content.foundControlFlowReachableSqlSinkMatchQualifiedName = fqn
    , Content.foundControlFlowReachableSqlSinkMatchKind = classifyKind fqn
    }

-- | First-cut SqlRaw vs SqlPreparedStatement classifier. Pattern-matches
-- on the FQN tail -- works for both the raw `@prisma/client.PrismaClient`
-- family AND project-side re-exports ( eg
-- `@formbricks/database.prisma.<model>.<method>` ).
classifyKind :: String -> Content.SqlSinkKind
classifyKind fqn
    | ".$queryRawUnsafe"   `isSuffixOf` fqn = Content.SqlRaw
    | ".$executeRawUnsafe" `isSuffixOf` fqn = Content.SqlRaw
    | ".$queryRaw"         `isSuffixOf` fqn = Content.SqlRaw
    | ".$executeRaw"       `isSuffixOf` fqn = Content.SqlRaw
    | ".$transaction"      `isSuffixOf` fqn = Content.SqlRaw
    | otherwise                             = Content.SqlPreparedStatement

-- | Pre-aggregated per-kind count. Payload contract (`Content.hs`) :
-- every `SqlSinkKind` constructor must appear in the counts list
-- ( zero-filled when absent ) so callers can direct-lookup.
countsByKind :: [Content.FoundControlFlowReachableSqlSinkMatch]
            -> [Content.SqlSinkKindCount]
countsByKind matches =
    let raws = length (filter (sameKind Content.SqlRaw) matches)
        preps = length matches - raws
    in [ Content.SqlSinkKindCount Content.SqlRaw (fromIntegral raws)
       , Content.SqlSinkKindCount Content.SqlPreparedStatement (fromIntegral preps)
       ]

sameKind :: Content.SqlSinkKind
         -> Content.FoundControlFlowReachableSqlSinkMatch
         -> Bool
sameKind k m = Content.foundControlFlowReachableSqlSinkMatchKind m == k

instantiateTemplate :: FilePath -> String -> Word -> Word -> IO T.Text
instantiateTemplate kbFilename sourceAtom numHops limit = do
    template <- TIO.readFile "templates/templateControlFlowReachableSqlSink.pl"
    pure (T.replace "{LIMIT}"           (T.pack (show limit))
         (T.replace "{LIMIT_NUM_HOPS}"  (T.pack (show numHops))
         (T.replace "{SOURCE_ATOM}"     (T.pack sourceAtom)
         (T.replace "{KNOWLEDGE_BASE}"  (T.pack kbFilename) template))))

decodeFqns :: Maybe (Stdout, a) -> [String]
decodeFqns (Just (Stdout out, _)) = mapMaybe decodeFqnLine (lines out)
decodeFqns _ = []

-- | Decode one line of the form `Fqn('@foo.bar.baz')` into `@foo.bar.baz`.
-- Returns `Nothing` for non-match lines ( warnings, blank lines, ... )
-- so `mapMaybe` filters them out cleanly.
decodeFqnLine :: String -> Maybe String
decodeFqnLine line = do
    inner <- stripPrefix "Fqn(" (trim line)
    quoted <- stripSuffixStr ")" inner
    stripOuterSingleQuotes quoted

trim :: String -> String
trim = dropWhile isSpace . dropWhileEnd isSpace

stripSuffixStr :: String -> String -> Maybe String
stripSuffixStr suffix value =
    if suffix `isSuffixOf` value
        then Just (take (length value - length suffix) value)
        else Nothing

-- | Prolog `format("~q", [Fqn])` wraps atoms containing dots / dollars
-- in single quotes. Strip them so the Haskell-side classifier sees
-- the plain FQN. If no quotes are present ( shouldn't happen for
-- our FQN shape, but be defensive ), return as-is.
stripOuterSingleQuotes :: String -> Maybe String
stripOuterSingleQuotes s@('\'' : rest) =
    case reverse rest of
        ('\'' : innerRev) -> Just (reverse innerRev)
        _ -> Just s
stripOuterSingleQuotes s = Just s
