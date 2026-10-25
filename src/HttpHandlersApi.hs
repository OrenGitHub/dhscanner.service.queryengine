{-# LANGUAGE OverloadedStrings #-}

-- | Handler for the `SelectHttpHandlers` kbapi query : every handler
-- `endpoints_http/4` recognizes, filtered by verb, authentication and
-- url parts ( `templates/templateHttpHandlers.pl` ).
module HttpHandlersApi
    ( query
    ) where

import Kbapi (QueryResult(..))
import Location (Location)
import qualified WithHttpHandlers as Q
import ApiEnv (ApiEnv)
import JsonTemplate (runJsonTemplate, atomLocation, prologString, prologAtoms)
import Data.Aeson (FromJSON(..), withObject, (.:), (.:?))
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.List as List
import qualified Data.Set as Set

data Handler = Handler String String String Def [ Input ] (Maybe Auth)

data Def = Def String (Maybe String) (Maybe String)

data Input = Input String String (Maybe String)

data Auth = Auth String String (Maybe String)

instance FromJSON Handler where
    parseJSON = withObject "Handler" (\o -> Handler
        <$> o .: "location"
        <*> o .: "verb"
        <*> o .: "url"
        <*> o .: "def"
        <*> o .: "userInputs"
        <*> o .:? "auth")

instance FromJSON Def where
    parseJSON = withObject "Def" (\o -> Def <$> o .: "kind" <*> o .:? "name" <*> o .:? "className")

instance FromJSON Input where
    parseJSON = withObject "Input" (\o -> Input <$> o .: "kind" <*> o .: "location" <*> o .:? "name")

instance FromJSON Auth where
    parseJSON = withObject "Auth" (\o -> Auth <$> o .: "name" <*> o .: "evidence" <*> o .:? "headerKey")

query :: Q.Features -> ApiEnv QueryResult
query features = do
    reply <- runJsonTemplate "HttpHandlers" "templates/templateHttpHandlers.pl"
        [ ("{VERBS}", prologAtoms (map verbAtom (Set.toList (Q.verbs features))))
        , ("{AUTHENTICATIONS}", prologAtoms (map authAtom (Set.toList (Q.authentications features))))
        , ("{URL_PARTS}", maybe "none" urlParts (Q.routeContainsUrlParts features))
        , ("{LIMIT}", show (Q.maxNumHttpHandlers features))
        ]
    let matches = mapMaybe buildHandler (fromMaybe [] reply)
    pure (FoundHttpHandlers Q.Content
        { Q.total = fromIntegral (length matches)
        , Q.matches = matches
        })

urlParts :: [ String ] -> String
urlParts parts = "[" ++ List.intercalate ", " (map prologString parts) ++ "]"

verbAtom :: Q.HttpVerb -> String
verbAtom Q.Get = "get"
verbAtom Q.Post = "post"
verbAtom Q.Put = "put"
verbAtom Q.Delete = "delete"
verbAtom Q.Patch = "patch"
verbAtom Q.Unknown = "unknown"

authAtom :: Q.AuthFilter -> String
authAtom Q.Unauthenticated = "unauthenticated"
authAtom Q.Authenticated = "authenticated"

buildVerb :: String -> Maybe Q.HttpVerb
buildVerb "get" = Just Q.Get
buildVerb "post" = Just Q.Post
buildVerb "put" = Just Q.Put
buildVerb "delete" = Just Q.Delete
buildVerb "patch" = Just Q.Patch
buildVerb "unknown" = Just Q.Unknown
buildVerb _ = Nothing

buildHandler :: Handler -> Maybe Q.HttpHandler
buildHandler (Handler atom verb url def inputs auth) = do
    loc <- atomLocation atom
    verb' <- buildVerb verb
    def' <- buildDef def
    auth' <- traverse buildAuth auth
    pure Q.HttpHandler
        { Q.httpHandlerVerb = verb'
        , Q.httpHandlerLocation = loc
        , Q.httpHandlerDef = def'
        , Q.httpHandlerUrl = url
        , Q.httpHandlerUserInputs = mapMaybe buildInput inputs
        , Q.httpHandlerAuth = auth'
        }

buildDef :: Def -> Maybe Q.HttpHandlerDef
buildDef (Def "MethodOfClass" (Just name) (Just className)) = Just (Q.MethodOfClass (Q.MethodName name) (Q.ClassName className))
buildDef (Def "NamedFunction" (Just name) _) = Just (Q.NamedFunction (Q.FunctionName name))
buildDef (Def "AnonymousFunction" _ _) = Just Q.AnonymousFunction
buildDef _ = Nothing

buildInput :: Input -> Maybe Q.UserInput
buildInput (Input kind atom name) = atomLocation atom >>= buildInput' kind (fromMaybe "" name)

buildInput' :: String -> String -> Location -> Maybe Q.UserInput
buildInput' "RequestObject" _ loc = Just (Q.RequestObjectCtor (Q.RequestObject loc))
buildInput' "RequestParam" name loc = Just (Q.RequestParamCtor (Q.RequestParam name loc))
buildInput' "PathVariable" _ loc = Just (Q.PathVariableCtor (Q.PathVariable loc))
buildInput' "RequestBody" _ loc = Just (Q.RequestBodyCtor (Q.RequestBody loc))
buildInput' "RequestHeader" _ loc = Just (Q.RequestHeaderCtor (Q.RequestHeader loc))
buildInput' "CookieValue" _ loc = Just (Q.CookieValueCtor (Q.CookieValue loc))
buildInput' "RequestPart" _ loc = Just (Q.RequestPartCtor (Q.RequestPart loc))
buildInput' _ _ _ = Nothing

buildAuth :: Auth -> Maybe Q.Authentication
buildAuth (Auth name evidence headerKey) = do
    evidence' <- buildEvidence evidence headerKey
    pure Q.Authentication
        { Q.authenticationFunctionName = name
        , Q.authenticationEvidence = evidence'
        }

buildEvidence :: String -> Maybe String -> Maybe Q.AuthEvidence
buildEvidence "ByHeaderNullCheck" (Just headerKey) = Just (Q.ByHeaderNullCheck headerKey)
buildEvidence "ByAllButOneBadReturn" _ = Just Q.ByAllButOneBadReturn
buildEvidence _ _ = Nothing
