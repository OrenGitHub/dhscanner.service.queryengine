{-# LANGUAGE OverloadedStrings #-}

-- | Shared runner for query templates whose `main/0` prints its answer as
-- a single JSON document ( `library(http/json)` ), so handlers decode the
-- reply with aeson instead of hand-parsing Prolog terms.
--
-- Location atoms travel as JSON strings and come back through
-- `Kbgen.restoreloc`.
module JsonTemplate
    ( runJsonTemplate
    , atomLocation
    , prologString
    , prologAtoms
    ) where

import qualified Location
import Kbgen (restoreloc)
import ApiEnv (ApiEnv, asksKbFilename)
import Swipl (saveAsMainFile, runSwiplWithTimeout, Stdout(..))
import Data.Aeson (FromJSON, decodeStrict)
import Data.Maybe (listToMaybe, mapMaybe)
import qualified Data.List as List
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Encoding as TE
import Control.Monad.IO.Class (liftIO)

-- | Fill @{KNOWLEDGE_BASE}@ plus the given slots into the template, run
-- it, and decode the last JSON line it prints. 'Nothing' on a timeout,
-- a Prolog error ( non-zero exit ) or an undecodable reply.
runJsonTemplate :: FromJSON a => String -> FilePath -> [ (T.Text, String) ] -> ApiEnv (Maybe a)
runJsonTemplate queryName templatePath slots = do
    kbFilename <- asksKbFilename
    liftIO (putStrLn ("[queryengine][api] " ++ queryName ++ " using kb: " ++ kbFilename))
    template <- liftIO (TIO.readFile templatePath)
    let program = List.foldl' fillSlot template (("{KNOWLEDGE_BASE}", kbFilename) : slots)
    path <- liftIO (saveAsMainFile program)
    liftIO (putStrLn ("[queryengine][api] SWI-Prolog main file path: " ++ path))
    outputOrTimeout <- liftIO (runSwiplWithTimeout path)
    pure (decodeOutput outputOrTimeout)

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
