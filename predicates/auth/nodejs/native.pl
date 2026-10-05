:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Nodejs runtime auth leaves.
%
% Everything in this file is tied to the `nodejs.*` resolved-FQN
% namespace emitted by the TS parser ( `nodejs.Request.headers.get`,
% `nodejs.Response.json`, `nodejs.crypto.*`, `nodejs.jsonwebtoken.*`,
% `nodejs.jose.*` ) + the FirstPartyImport Haskell-Show atom format
% used by `kb_call_resolved` for method calls on 1st-party imported
% objects. Both Express and Next.js endpoints share this runtime, so
% there is no further nextjs/express split at this layer. If a
% framework-specific divergence ever appears, promote the diverging
% clauses to `predicates/auth/nodejs/<framework>.pl`.

% -----------------------------------------------------------------------------
% auth_early_return_null_on_missing_request_header_value( Callable, KeyName )
%
% Recognises the strict-tier "early return null on missing request-header
% value" idiom. Concretely, inside `Callable` :
%
%     const V = request.headers.get( 'X-Api-Key' );
%     if ( !V ) return null;
%
% Composed from four ingredients :
%
%   1. `kb_called_from` + `kb_call_resolved`  : a call to
%      `nodejs.Request.headers.get` occurs inside Callable.
%
%   2. `kb_arg_i_for_call` + `kb_const_string`: the header key name is a
%      compile-time string ( bound to `KeyName` for downstream ranking ).
%
%   3. `kb_gated_return_null`                  : an early-return guard
%      whose returned value is a null literal ( derived on top of the
%      more general `kb_gated_return( Cond, ReturnedValue )` fact ).
%
%   4. `dataflow_intra_path`                   : intra-procedural
%      dataflow ties `headers.get( KeyName )` -> gate condition value.
%
% This is the *strict tier* of the "authenticating function" first gate.
% The nodejs/nextjs surface receiver is hardcoded here; sibling clauses
% for other frameworks / receivers can be added as leaf additions -- no
% existing clause needs to change.

auth_early_return_null_on_missing_request_header_value( Callable, KeyName ) :-
    kb_called_from( Call, Callable ),
    kb_call_resolved( Call, 'nodejs.Request.headers.get' ),
    kb_arg_i_for_call( KeyArg, 0, Call ),
    kb_const_string( KeyArg, KeyName ),
    kb_gated_return_null( Cond ),
    dataflow_intra_path( Call, Cond, _ ).

% kb_gated_return_null( Cond ) : an early-return guard whose returned
% value is a language-level absence literal ( `null`, `None`, `nil` --
% all normalised to the same `kb_const_null` fact by kbgen ). Layered on
% top of the more general `kb_gated_return` fact so that sibling
% derivations ( e.g. `kb_gated_return_false`, `kb_gated_throw`, ... )
% can be added later as pure leaf additions.

kb_gated_return_null( Cond ) :-
    kb_gated_return( Cond, ReturnedValue ),
    kb_const_null( ReturnedValue ).

% -----------------------------------------------------------------------------
% auth_function_returns_bad_http_response_ts_{401,403,404}( Function )
%
% TypeScript / nodejs branch of the "function returns a bad-http
% response somewhere in its body" primitive. The language-agnostic
% dispatcher ( `auth_function_returns_bad_http_response_ts/1` ) lives
% in predicates/auth/common.pl and ORs these three per-code leaves ;
% add 400 / 405 / 409 / 422 / 429 / 500 / ... as pure leaf additions
% here + one more OR clause there.
%
% Structural pattern for TypeScript / nodejs :
%
%     Response.json( <body>, { status: <bad-code> } )
%
% After ts-parser-actions instrumentation this becomes the ast call
% tree :
%
%     Response.json( <body>, dictify( kv( "status", <bad-code> ) ) )
%
% ( see `TsParser.y::exp_dict` -- object literals lower to a call
% whose callee is the bare name `dictify` ; and
% `TsParserActions.hs::property` lowers each `k: v` pair to a call
% whose callee is the instrumented bare name
% `<dhscanner-instrumentation>[kv]` with args `[ k, v ]` -- casing is
% exact ).
%
% Known kbgen gap ( scaffolded here, activated by a follow-up version
% bump ) : `kb_const_int( Loc, Value )` is not emitted today ( only
% kb_const_string / kb_const_bool_true exist -- see
% `Kbgen.hs::prologify_*` ). Every leaf below already carries its code
% as data, so adding kb_const_int to kbgen is a *pure activation* : no
% edit needed here to start discriminating 401 from 403 from 404.

auth_function_returns_bad_http_response_ts_401(Function) :-
    auth_ts_response_json_with_status(Function, 401).
auth_function_returns_bad_http_response_ts_403(Function) :-
    auth_ts_response_json_with_status(Function, 403).
auth_function_returns_bad_http_response_ts_404(Function) :-
    auth_ts_response_json_with_status(Function, 404).

% Structural walk from the outer `nodejs.Response.json` call down
% through the `dictify( kv( "status", Code ) )` instrumented dict.
%
% NOTE: `kb_arg_i_for_call( Arg, Index, Call )` is emitted by kbgen
% with Call = Bitcode.callLocation and Arg = Bitcode.locationValue of
% each arg value ( see `Factify.hs::getArgiForCallFacts` ). For the
% recursive descent into `DictifyCallLoc` and `KvCallLoc` below to
% unify, those two locations must coincide on call-valued args --
% true in SSA-style bitcode, but verify against a real KB the first
% time this predicate is exercised end-to-end.
auth_ts_response_json_with_status(Function, Code) :-
    kb_call_resolved(OuterCall, 'nodejs.Response.json'),
    kb_arg_i_for_call(DictifyCallLoc, 1, OuterCall),
    kb_arg_i_for_call(KvCallLoc, _, DictifyCallLoc),
    kb_arg_i_for_call(KeyLoc, 0, KvCallLoc),
    kb_const_string(KeyLoc, 'status'),
    kb_arg_i_for_call(ValueLoc, 1, KvCallLoc),
    kb_const_int(ValueLoc, Code),
    kb_called_from(OuterCall, Function).

% -----------------------------------------------------------------------------
% auth_return_value_is_bad_http_response_ts_{401,403,404}( ReturnedValue )
%
% Return-value-anchored twins of the per-function leaves above --
% anchored on a specific `return` location rather than on the enclosing
% callable. The common.pl dispatcher
% `auth_return_value_is_bad_http_response_ts/1` ORs these plus the
% `_via_1st_party_wrapper/1` 1-hop wrapper clause below.

auth_return_value_is_bad_http_response_ts_401(ReturnedValue) :-
    auth_ts_response_json_at_with_status(ReturnedValue, 401).
auth_return_value_is_bad_http_response_ts_403(ReturnedValue) :-
    auth_ts_response_json_at_with_status(ReturnedValue, 403).
auth_return_value_is_bad_http_response_ts_404(ReturnedValue) :-
    auth_ts_response_json_at_with_status(ReturnedValue, 404).

% 1-hop wrapper case : the returned value is a call to a 1st-party
% helper whose body itself contains a bad-http response call.
% Real-world guards rarely inline `Response.json( ... )` directly at
% each `return` site -- they call a named helper like
% `responses.notAuthenticatedResponse()` or
% `responses.unauthorizedResponse()` which wraps the actual
% Response.json one hop deeper. This clause is what makes the shape
% recogniser fire on those guards without requiring the helpers to be
% inlined.
%
% Method-call-on-imported-object case ( eg
% `responses.notAuthenticatedResponse()` ) : kbgen resolves such calls
% through `kb_call_resolved` with a Haskell-Show-formatted qualifier
% atom of the form
%
%    'FirstPartyImport (FirstPartyImportContent {firstPartyImportedLocation = "<File>", firstPartyImportedName = Just "<Qual>"}).<Method>'
%
% `auth_1st_party_wrapper_helper/2` splits that atom on `"` to recover
% the wrapper's defining file + method name and binds Helper via
% `kb_func_def/4`. From there we recurse the LEAF bad-http checkers
% ( `_ts_401` / `_ts_403` / `_ts_404` ) on the wrapper's own returns
% ( `kb_callable_returns_value/2` -- emitted for every explicit return
% plus the parser-injected fall-through, see
% `TsParserActions.hs::ensureCallableBodyEndsWithReturn` ).
%
% Bypassing `kb_call_1st_party_func_defined_in_file/3` here is
% deliberate. That fact is only emitted for BARE function calls (
% `hasPermission(...)` etc. ), not for method calls on imported
% objects -- which is exactly the shape every real-world
% response-helper follows in the formbricks codebase ( and,
% empirically, in every other nextjs app we've looked at ).
%
% Calling `_ts_401` / `_ts_403` / `_ts_404` directly ( rather than
% the dispatcher ) caps recursion at exactly one wrapper hop. A
% future multi-hop version ( eg a wrapper that itself wraps another
% wrapper ) can leaf-add a dedicated `_via_1st_party_wrapper_wrapper`
% clause without touching the leaves.
auth_return_value_is_bad_http_response_via_1st_party_wrapper(ReturnedValue) :-
    auth_1st_party_wrapper_helper(ReturnedValue, Helper),
    kb_callable_returns_value(Helper, HelperReturn),
    auth_return_value_is_bad_http_response_ts_401(HelperReturn).
auth_return_value_is_bad_http_response_via_1st_party_wrapper(ReturnedValue) :-
    auth_1st_party_wrapper_helper(ReturnedValue, Helper),
    kb_callable_returns_value(Helper, HelperReturn),
    auth_return_value_is_bad_http_response_ts_403(HelperReturn).
auth_return_value_is_bad_http_response_via_1st_party_wrapper(ReturnedValue) :-
    auth_1st_party_wrapper_helper(ReturnedValue, Helper),
    kb_callable_returns_value(Helper, HelperReturn),
    auth_return_value_is_bad_http_response_ts_404(HelperReturn).

% Extract the wrapper's ( DefFile, Method ) from a `kb_call_resolved`
% whose resolved-name atom follows the FirstPartyImport Haskell-Show
% format documented above. Splits on `"` and re-checks structural
% anchors so non-FirstPartyImport shapes ( `os/exec.Command`,
% `nodejs.Response.json`, `Yii.app.db.createCommand.queryAll`, etc. )
% cleanly FAIL rather than return garbage extractions :
%
%   Chunk[0] -- unused ; the fixed prefix
%              `FirstPartyImport (... firstPartyImportedLocation = `.
%   Chunk[1] -- the file path, bound to `File`.
%   Chunk[2..3] -- unused ; the qualifier name between the quotes.
%   Chunk[4] -- starts with `}).` followed by the method name ;
%              stripping the sentinel binds `Method`.
%
% The 5-part unification is the actual reject-non-matching-shapes gate
% -- atoms without four `"` characters ( eg `os/exec.Command` )
% produce a 1-element split_string result and fail here immediately.
auth_1st_party_wrapper_helper(ReturnedValue, Helper) :-
    kb_call_resolved(ReturnedValue, ResolvedName),
    atom_string(ResolvedName, S),
    split_string(S, "\"", "", [_, FileStr, _, _, TailStr]),
    string_concat("}).", MethodStr, TailStr),
    atom_string(File, FileStr),
    atom_string(Method, MethodStr),
    kb_func_def(Helper, Method, File, _).

% Same structural walk as `auth_ts_response_json_with_status/2` above,
% but anchored on the outer call location ( which coincides with the
% return value's location when the return is `return Response.json( ... )` )
% rather than on the enclosing callable. The per-function form composes
% trivially on top of this predicate :
%
%     auth_ts_response_json_with_status( Function, Code ) :-
%         auth_ts_response_json_at_with_status( OuterCall, Code ),
%         kb_called_from( OuterCall, Function ).
%
% Existing per-function walker is kept inline to keep diffs narrow ;
% a follow-up can refactor it to route through this predicate.
%
% The `kb_const_string( KeyLoc, 'status' )` gate keeps this walker
% honest : without it, ANY int-valued kv-pair inside `Response.json`'s
% init-options bag would match ( eg `{ retryAfter: 401 }`, hypothetical
% but possible ). The gate depends on kbgen emitting `kb_const_string`
% for object-literal identifier-form keys ( `{ status: 401 }` ) --
% NOT only for quoted-string keys ( `{ "status": 401 }` ). See the
% `property_key` non-terminal in `TsParser.y` : it lowers BOTH
% `StringLiteral` and `Identifier` in the key position of a
% `PropertyAssignment` to `Ast.ExpStr`, so both flow through
% `getConstStringsFromValue`'s `Bitcode.ConstStrValue` branch in
% `Factify.hs`. Requires parsers >= 1.1.18-x64 ; earlier images
% lowered identifier-form keys as `Ast.ExpVar` and this gate
% silently blocked the walker.
auth_ts_response_json_at_with_status(Call, Code) :-
    kb_call_resolved(Call, 'nodejs.Response.json'),
    kb_arg_i_for_call(DictifyCallLoc, 1, Call),
    kb_arg_i_for_call(KvCallLoc, _, DictifyCallLoc),
    kb_arg_i_for_call(KeyLoc, 0, KvCallLoc),
    kb_const_string(KeyLoc, 'status'),
    kb_arg_i_for_call(ValueLoc, 1, KvCallLoc),
    kb_const_int(ValueLoc, Code).

% -----------------------------------------------------------------------------
% auth_crypto_leaf_call( Call )
%
% Tier-1 crypto-leaf catalog. Each clause asserts that `Call` resolves
% to a well-known cryptographic primitive whose *output* is the value
% typically compared against untrusted input in a capability-verifier
% shape. Leaf-only : downstream predicates ( in particular
% `auth_capability_verifier_by_shape/1` in common.pl ) treat every
% clause the same, so new libraries / runtimes are pure leaf additions.

auth_crypto_leaf_call(Call) :- kb_call_resolved(Call, 'nodejs.crypto.createHmac.update.digest').
auth_crypto_leaf_call(Call) :- kb_call_resolved(Call, 'nodejs.crypto.timingSafeEqual').
auth_crypto_leaf_call(Call) :- kb_call_resolved(Call, 'nodejs.jsonwebtoken.verify').
auth_crypto_leaf_call(Call) :- kb_call_resolved(Call, 'nodejs.jose.jwtVerify').
% add more crypto-leaf FQNs here ...
