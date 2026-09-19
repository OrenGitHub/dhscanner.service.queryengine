{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the UnauthenticatedHttpPutHandlerRequestObject kbapi query.
-- PUT counterpart of 'UnauthenticatedHttpPostHandlerRequestObjectApi'.
-- Same 3-line decoding shape ("PutHandler / Request / Url") -- no auth
-- metadata because there is no auth call to name. Reuses the shared
-- 'Content.FoundHttpPutHandlerRequestObjectMatch' record type.
module UnauthenticatedHttpPutHandlerRequestObjectApi
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

query :: Content.UnauthenticatedHttpPutHandlerRequestObject -> ApiEnv QueryResult
query (Content.UnauthenticatedHttpPutHandlerRequestObject _ limit) = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] UnauthenticatedHttpPutHandlerRequestObject using kb: " ++ kbFilename))
    program <- liftIO (instantiateTemplate kbFilename limit)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    outputOrTimeout <- liftIO (runSwiplWithTimeout path)
    let matches = decodeMatches outputOrTimeout
    pure (FoundUnauthenticatedHttpPutHandlerRequestObject Content.FoundUnauthenticatedHttpPutHandlerRequestObject
        { Content.foundUnauthenticatedHttpPutHandlerRequestObjectTotal = fromIntegral (length matches)
        , Content.foundUnauthenticatedHttpPutHandlerRequestObjectMatches = matches
        })

instantiateTemplate :: FilePath -> Word -> IO T.Text
instantiateTemplate kbFilename limit = do
    template <- TIO.readFile "templates/templateUnauthenticatedHttpPutHandlerRequestObject.pl"
    pure (T.replace "{LIMIT}" (T.pack (show limit))
        (T.replace "{KNOWLEDGE_BASE}" (T.pack kbFilename) template))

decodeMatches :: Maybe (Stdout, a) -> [ Content.FoundHttpPutHandlerRequestObjectMatch ]
decodeMatches (Just (Stdout out, _)) = mapMaybe decodeMatch (extractMatchBlocks out)
decodeMatches _ = []

decodeMatch :: [String] -> Maybe Content.FoundHttpPutHandlerRequestObjectMatch
decodeMatch rawLines = do
    (handlerLine:requestLine:urlLine:[]) <- Just (map trim (filter (not . all isSpace) rawLines))
    handler <- parseTaggedTerm "PutHandler" handlerLine
    request <- parseTaggedTerm "Request" requestLine
    url <- parseTaggedTerm "Url" urlLine
    handlerLoc <- restoreloc handler
    loc <- restoreloc request
    pure Content.FoundHttpPutHandlerRequestObjectMatch
        { Content.foundHttpPutHandlerLocation = handlerLoc
        , Content.foundHttpPutHandlerRequestObjectLocation = loc
        , Content.foundHttpPutHandlerRequestObjectMatchUrl = url
        }

parseTaggedTerm :: String -> String -> Maybe String
parseTaggedTerm tag line = do
    inner <- stripPrefix (tag ++ "(") (trim line)
    stripSuffix ")" inner

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
