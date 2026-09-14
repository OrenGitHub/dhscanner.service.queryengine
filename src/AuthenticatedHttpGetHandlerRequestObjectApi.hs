{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the AuthenticatedHttpGetHandlerRequestObject kbapi query.
-- GET counterpart of 'AuthenticatedHttpPostHandlerRequestObjectApi' -- same
-- shape, same decoding pipeline, same auth-metadata surfacing. The two
-- files are intentionally near-duplicates: they share zero code because
-- they parse different Prolog output ("GetHandler(...)" vs "PostHandler(...)")
-- and populate different Content record shapes, but the /structure/ is
-- identical. When adding a third HTTP verb (e.g. PATCH) mirror this file.
module AuthenticatedHttpGetHandlerRequestObjectApi
    ( query
    ) where

import qualified Content
import Kbapi (QueryResult(..))
import Kbgen (restoreloc)
import ApiEnv (ApiEnv, asksKbFilename)
import Swipl (saveAsMainFile, runSwiplWithTimeout, Stdout(..))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Maybe (mapMaybe)
import Data.Char (isSpace)
import Data.List (stripPrefix)
import Data.List (dropWhileEnd)
import Control.Monad.IO.Class (liftIO)

query :: Content.AuthenticatedHttpGetHandlerRequestObject -> ApiEnv QueryResult
query (Content.AuthenticatedHttpGetHandlerRequestObject _ limit) = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] AuthenticatedHttpGetHandlerRequestObject using kb: " ++ kbFilename))
    program <- liftIO (instantiateTemplate kbFilename limit)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    outputOrTimeout <- liftIO (runSwiplWithTimeout path)
    let matches = decodeMatches outputOrTimeout
    pure (FoundAuthenticatedHttpGetHandlerRequestObject Content.FoundAuthenticatedHttpGetHandlerRequestObject
        { Content.foundAuthenticatedHttpGetHandlerRequestObjectTotal = fromIntegral (length matches)
        , Content.foundAuthenticatedHttpGetHandlerRequestObjectMatches = matches
        })

instantiateTemplate :: FilePath -> Word -> IO T.Text
instantiateTemplate kbFilename limit = do
    template <- TIO.readFile "templates/templateAuthenticatedHttpGetHandlerRequestObject.pl"
    pure (T.replace "{LIMIT}" (T.pack (show limit))
        (T.replace "{KNOWLEDGE_BASE}" (T.pack kbFilename) template))

decodeMatches :: Maybe (Stdout, a) -> [ Content.FoundAuthenticatedHttpGetHandlerRequestObjectMatch ]
decodeMatches (Just (Stdout out, _)) = mapMaybe decodeMatch (extractMatchBlocks out)
decodeMatches _ = []

-- | Parses one 5-line block emitted by
-- `templateAuthenticatedHttpGetHandlerRequestObject.pl`:
--
--     GetHandler(<location-atom>)
--     Request(<location-atom>)
--     Url(<url-atom-or-string>)
--     AuthFuncName(<name-atom>)
--     AuthEvidence(<evidence-compound-term>)
--
-- Structural twin of the POST /5 handler ; the only difference is the
-- leading "GetHandler(...)" tag vs "PostHandler(...)". See that file
-- for the block-comment on 'parseAuthEvidence' + the leaf-addition
-- discipline for new 'Content.AuthEvidence' variants.
decodeMatch :: [String] -> Maybe Content.FoundAuthenticatedHttpGetHandlerRequestObjectMatch
decodeMatch rawLines = do
    (handlerLine:requestLine:urlLine:authFuncLine:evidenceLine:[]) <- Just (map trim (filter (not . all isSpace) rawLines))
    handler <- parseTaggedTerm "GetHandler" handlerLine
    request <- parseTaggedTerm "Request" requestLine
    url <- parseTaggedTerm "Url" urlLine
    authFuncName <- parseTaggedTerm "AuthFuncName" authFuncLine
    evidence <- parseAuthEvidence evidenceLine
    handlerLoc <- restoreloc handler
    loc <- restoreloc request
    pure Content.FoundAuthenticatedHttpGetHandlerRequestObjectMatch
        { Content.foundAuthenticatedHttpGetHandlerLocation = handlerLoc
        , Content.foundAuthenticatedHttpGetHandlerRequestObjectLocation = loc
        , Content.foundAuthenticatedHttpGetHandlerRequestObjectMatchUrl = unquotePrologAtom url
        , Content.foundAuthenticatedHttpGetHandlerAuthenticatingFunctionName = unquotePrologAtom authFuncName
        , Content.foundAuthenticatedHttpGetHandlerAuthEvidence = evidence
        }

parseTaggedTerm :: String -> String -> Maybe String
parseTaggedTerm tag line = do
    inner <- stripPrefix (tag ++ "(") (trim line)
    stripSuffix ")" inner

-- | Decodes one @AuthEvidence(...)@ line into the 'Content.AuthEvidence'
-- sum. GET twin of the POST /5 handler's parser -- kept locally
-- ( zero shared code between the two handlers ) so the two files stay
-- self-contained and can diverge independently if a verb-specific
-- evidence variant is ever needed. See the POST /5 handler for the
-- fuller haddock and constructor catalog.
parseAuthEvidence :: String -> Maybe Content.AuthEvidence
parseAuthEvidence line = do
    inner <- parseTaggedTerm "AuthEvidence" line
    parseEvidenceTerm (trim inner)

parseEvidenceTerm :: String -> Maybe Content.AuthEvidence
parseEvidenceTerm s = case break (== '(') s of
    ("by_all_but_one_bad_return", "") ->
        Just Content.ByAllButOneBadReturn
    ("by_header_null_check", '(':rest) -> do
        payload <- stripSuffix ")" rest
        pure (Content.ByHeaderNullCheck (unquotePrologAtom (trim payload)))
    _ -> Nothing

-- | Strips the single-quote wrapper Prolog's `~q` adds around atoms
-- with characters that would otherwise need quoting (hyphens, dots,
-- slashes, ...). Leaves already-bare atoms untouched.
unquotePrologAtom :: String -> String
unquotePrologAtom s = case s of
    ('\'':rest) | not (null rest) && last rest == '\'' -> init rest
    _ -> s

trim :: String -> String
trim = dropWhile isSpace . dropWhileEnd isSpace

stripSuffix :: String -> String -> Maybe String
stripSuffix suffix value =
    if suffix == reverse (take (length suffix) (reverse value))
        then Just (take (length value - length suffix) value)
        else Nothing

extractMatchBlocks :: String -> [[String]]
extractMatchBlocks = reverse . finalize . foldl step ([], []) . lines
  where
    step :: ([[String]], [String]) -> String -> ([[String]], [String])
    step (blocks, current) line
        | all isSpace line =
            if null current
                then (blocks, current)
                else (reverse current : blocks, [])
        | otherwise = (blocks, line : current)

    finalize :: ([[String]], [String]) -> [[String]]
    finalize (blocks, []) = blocks
    finalize (blocks, current) = reverse current : blocks
