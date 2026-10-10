{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `ControlFlowReachableFileActionSink` kbapi query.
--
-- Direct analogue of `ControlFlowReachableSqlSinkApi` -- same template
-- instantiation shape, same SWI-Prolog invocation, same `Fqn(...)`
-- decoding envelope ; swaps the SQL-flavored template +
-- classification for the file-action-flavored equivalents.
--
-- Membership is decided Prolog-side ( substring probes on
-- `.writeFile` / `.appendFile` ; extensible per-family in the
-- template ). The structural `FileActionKind` classification is
-- decided here on the returned FQN tail.
--
-- Classification table :
--
--   anything containing `.writeFile`  / `.appendFile` -> `FileWrite`
--   anything containing `.readFile`                   -> `FileRead`
--   anything containing `.unlink`     / `.rmdir`      -> `FileDelete`
--
-- The classifier is kept in strict agreement with
-- `is_file_action_sink_fqn/1` in the Prolog template -- every
-- substring probe accepted there has a matching tail check here.
-- Adding a new sink family is a two-site change ( Prolog clause +
-- Haskell `isInfixOf` guard ).
--
-- Per-match `Location` is the input source handler itself for now ;
-- surfacing the sink call site is a follow-up refinement that will
-- plumb `CallSite` through a sibling closure predicate in `utils.pl`
-- ( same follow-up that is pending on `ControlFlowReachableSqlSinkApi` ).
module ControlFlowReachableFileActionSinkApi
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
import Data.List (isInfixOf, isSuffixOf, stripPrefix, dropWhileEnd)
import Control.Monad.IO.Class (liftIO)

query :: Content.ControlFlowReachableFileActionSink -> ApiEnv QueryResult
query (Content.ControlFlowReachableFileActionSink from numHops limit) = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] ControlFlowReachableFileActionSink using kb: " ++ kbFilename))
    let sourceAtom = locationify from
    liftIO (putStrLn ("[queryengine][api] source atom: " ++ sourceAtom))
    program <- liftIO (instantiateTemplate kbFilename sourceAtom numHops limit)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    outputOrTimeout <- liftIO (runSwiplWithTimeout path)
    let fqns = decodeFqns outputOrTimeout
    let matches = map (buildMatch from) fqns
    let total = fromIntegral (length matches)
    pure (FoundControlFlowReachableFileActionSink Content.FoundControlFlowReachableFileActionSink
        { Content.foundControlFlowReachableFileActionSinkTotal = total
        , Content.foundControlFlowReachableFileActionSinkCountsByKind = countsByKind matches
        , Content.foundControlFlowReachableFileActionSinkMatches = matches
        })

-- | Shape one reached FQN into a `FoundControlFlowReachableFileActionSinkMatch`.
-- Location is the source handler for the first cut ; sink-call-site
-- locations are a follow-up refinement.
buildMatch :: Location.Location -> String
           -> Content.FoundControlFlowReachableFileActionSinkMatch
buildMatch handlerLoc fqn = Content.FoundControlFlowReachableFileActionSinkMatch
    { Content.foundControlFlowReachableFileActionSinkMatchLocation = handlerLoc
    , Content.foundControlFlowReachableFileActionSinkMatchQualifiedName = fqn
    , Content.foundControlFlowReachableFileActionSinkMatchKind = classifyKind fqn
    }

-- | FileActionKind classifier. Pattern order matters only for FQNs
-- that satisfy multiple probes ( unlikely given the current catalog ) ;
-- in that case the first clause wins, which is a documented
-- fallback rather than a load-bearing invariant. The @otherwise@
-- fallback is defensive -- the Prolog-side membership filter
-- guarantees we never see an FQN here that does not satisfy at
-- least one probe, but if the catalog ever drifts, falling back
-- to `FileWrite` keeps the match visible rather than silently
-- dropped.
classifyKind :: String -> Content.FileActionKind
classifyKind fqn
    | ".writeFile"  `isInfixOf` fqn = Content.FileWrite
    | ".appendFile" `isInfixOf` fqn = Content.FileWrite
    | ".readFile"   `isInfixOf` fqn = Content.FileRead
    | ".unlink"     `isInfixOf` fqn = Content.FileDelete
    | ".rmdir"      `isInfixOf` fqn = Content.FileDelete
    | otherwise                     = Content.FileWrite

-- | Pre-aggregated per-kind count. Payload contract (`Content.hs`) :
-- every `FileActionKind` constructor must appear in the counts list
-- ( zero-filled when absent ) so callers can direct-lookup.
countsByKind :: [Content.FoundControlFlowReachableFileActionSinkMatch]
            -> [Content.FileActionKindCount]
countsByKind matches =
    let writes  = length (filter (sameKind Content.FileWrite)  matches)
        reads_  = length (filter (sameKind Content.FileRead)   matches)
        deletes = length (filter (sameKind Content.FileDelete) matches)
    in [ Content.FileActionKindCount Content.FileWrite  (fromIntegral writes)
       , Content.FileActionKindCount Content.FileRead   (fromIntegral reads_)
       , Content.FileActionKindCount Content.FileDelete (fromIntegral deletes)
       ]

sameKind :: Content.FileActionKind
         -> Content.FoundControlFlowReachableFileActionSinkMatch
         -> Bool
sameKind k m = Content.foundControlFlowReachableFileActionSinkMatchKind m == k

instantiateTemplate :: FilePath -> String -> Word -> Word -> IO T.Text
instantiateTemplate kbFilename sourceAtom numHops limit = do
    template <- TIO.readFile "templates/templateControlFlowReachableFileActionSink.pl"
    pure (T.replace "{LIMIT}"           (T.pack (show limit))
         (T.replace "{LIMIT_NUM_HOPS}"  (T.pack (show numHops))
         (T.replace "{SOURCE_ATOM}"     (T.pack sourceAtom)
         (T.replace "{KNOWLEDGE_BASE}"  (T.pack kbFilename) template))))

decodeFqns :: Maybe (Stdout, a) -> [String]
decodeFqns (Just (Stdout out, _)) = mapMaybe decodeFqnLine (lines out)
decodeFqns _ = []

-- | Decode one line of the form `Fqn('@foo.bar.baz')` into `@foo.bar.baz`.
-- Returns `Nothing` for non-match lines ( warnings, blank lines, ... )
-- so `mapMaybe` filters them out cleanly. Line envelope is identical
-- to the SQL template's output -- see
-- `templateControlFlowReachableFileActionSink.pl`'s `print_matches/1`.
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
