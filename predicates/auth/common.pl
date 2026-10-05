:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Language-agnostic auth recognizers.
%
% Every clause in this file reasons at the shape layer -- it never
% hardcodes a language/framework-specific FQN. The three framework
% dispatchers at the bottom ( _bad_http_response/_ts, _crypto_leaf_call,
% ... ) OR together the per-language leaves living under
% predicates/auth/<lang>/*.pl. Loading order ( see api.pl ) : language
% leaves first, this file second, so the dispatchers resolve cleanly
% against already-defined per-language intermediates.

% -----------------------------------------------------------------------------
% Dynamic empty catalogs.
%
% tier-1 NAME catalogs removed by design : structural recognition is
% the only evidence path. `:- dynamic` keeps the predicates defined
% so callers fail silently instead of throwing "Unknown procedure".
% Do NOT reintroduce hardcoded names here.

:- dynamic(auth_authenticating_function_name/1).
:- dynamic(auth_early_return_authenticating_function_name/1).
:- dynamic(auth_capability_verifier_name/1).

% -----------------------------------------------------------------------------
% auth_authenticating_function( Call, Name, Func )
% auth_authenticating_function( Call )
%
% /3 form -- binds Name and the resolved 1st-party function
% definition (Func) so callers can chain further structural checks
% against AuthFunc's body ( e.g.
% `auth_early_return_null_on_missing_request_header_value/2` in
% predicates/auth/nodejs/native.pl ).
%
% Four clauses : two tier-1-name-based ( file / dir ) + two
% shape-based ( file / dir, gated by
% `auth_authenticating_function_by_return_values/1` ). The name
% catalog is intentionally empty by design -- structural evidence IS
% the evidence. Name is still bound from the call-resolution fact so
% downstream callers ( kbapi ) get a human-readable label.

auth_authenticating_function(Call, Name, Func) :-
    kb_call_1st_party_func_defined_in_file(Call, Name, DefFile),
    auth_authenticating_function_name(Name),
    kb_func_def(Func, Name, DefFile, _).

auth_authenticating_function(Call, Name, Func) :-
    kb_call_1st_party_func_defined_in_dir(Call, Name, DefDir),
    auth_authenticating_function_name(Name),
    kb_func_def(Func, Name, _, DefDir).

auth_authenticating_function(Call, Name, Func) :-
    kb_call_1st_party_func_defined_in_file(Call, Name, DefFile),
    kb_func_def(Func, Name, DefFile, _),
    auth_authenticating_function_by_return_values(Func).

auth_authenticating_function(Call, Name, Func) :-
    kb_call_1st_party_func_defined_in_dir(Call, Name, DefDir),
    kb_func_def(Func, Name, _, DefDir),
    auth_authenticating_function_by_return_values(Func).

% /1 form -- retained as a thin projection over the /3 form so any
% legacy caller that only cared about "is this a call to an
% authenticator ?" keeps working.
auth_authenticating_function(Call) :- auth_authenticating_function(Call, _, _).

% -----------------------------------------------------------------------------
% auth_early_return_authenticating_function( Callable )
%
% Bounded "early-return authenticating function" recognition -- no
% transitive closure by design. Two levels only :
%   level-0 : base name catalog (
%             `auth_early_return_authenticating_function_name/1` ;
%             empty today, structural evidence pending )
%   level-1 : a callable that calls a level-0 authenticator ( single
%             hop )

auth_early_return_authenticating_function(Callable) :-
    kb_func_def(Callable, Name, _, _),
    auth_early_return_authenticating_function_name(Name).

auth_early_return_authenticating_function(Callable) :-
    kb_called_from(Call, Callable),
    auth_call_to_level_0_authenticator(Call).

auth_call_to_level_0_authenticator(Call) :-
    kb_call_1st_party_func_defined_in_file(Call, Name, _),
    auth_early_return_authenticating_function_name(Name).

auth_call_to_level_0_authenticator(Call) :-
    kb_call_1st_party_func_defined_in_dir(Call, Name, _),
    auth_early_return_authenticating_function_name(Name).

% -----------------------------------------------------------------------------
% auth_function_returns_bad_http_response( Function )
%
% Recognizes callables that emit an *error* http response ( 401 / 403
% / 404 / 500 / ... ). Together with the db-lookup polarity primitive,
% this is the second building block of the "happy-path authenticator
% polarity" compass discussed in the OWASP notes.
%
% Layered so that new languages / frameworks / codes are all leaf
% additions -- no existing clause needs to change to extend it :
%
%     auth_function_returns_bad_http_response( Function ).
%     |
%     +-- auth_function_returns_bad_http_response_ts( Function ).      % TypeScript ( nodejs.Response.json )
%     |   |
%     |   +-- auth_function_returns_bad_http_response_ts_401( F ).
%     |   +-- auth_function_returns_bad_http_response_ts_403( F ).
%     |   +-- auth_function_returns_bad_http_response_ts_404( F ).
%     |   ... add more "bad" codes here ( 400, 405, 409, 422, 429, 500, ... ) ...
%     |
%     ... add more kinds here ( _python, _go, _php, ... ) ...
%
% The `_ts_*` leaves live in predicates/auth/nodejs/native.pl ; this
% file only hosts the two language-agnostic dispatcher levels.

auth_function_returns_bad_http_response(Function) :-
    auth_function_returns_bad_http_response_ts(Function).
% add more languages / frameworks here ...

auth_function_returns_bad_http_response_ts(Function) :-
    auth_function_returns_bad_http_response_ts_401(Function).
auth_function_returns_bad_http_response_ts(Function) :-
    auth_function_returns_bad_http_response_ts_403(Function).
auth_function_returns_bad_http_response_ts(Function) :-
    auth_function_returns_bad_http_response_ts_404(Function).
% add more "bad" codes here ...

% -----------------------------------------------------------------------------
% auth_return_value_is_bad_http_response( ReturnedValue )
%
% Return-value-anchored refinement of
% `auth_function_returns_bad_http_response/1`. The per-function
% version answers "does Function contain, anywhere in its body, at
% least one bad-http response ?". This per-return version asks the
% stricter question "is THIS specific return statement's returned
% value a bad-http response ?" -- anchored on a ReturnedValue
% location bound by `kb_callable_returns_value/2` ( emitted by kbgen
% for every explicit return in a callable, plus one parser-injected
% fall-through at the callable's header location -- see
% `TsParserActions.hs::ensureCallableBodyEndsWithReturn` ).
%
% Same layering as the per-function form so new languages / codes
% remain pure leaf additions. The `_via_1st_party_wrapper/1` clause
% hooked into the `_ts/1` dispatcher captures the 1-hop
% "responses.notAuthenticatedResponse()"-style helper case -- see
% the leaf comment in predicates/auth/nodejs/native.pl.

auth_return_value_is_bad_http_response(ReturnedValue) :-
    auth_return_value_is_bad_http_response_ts(ReturnedValue).
% add more languages / frameworks here ...

auth_return_value_is_bad_http_response_ts(ReturnedValue) :-
    auth_return_value_is_bad_http_response_ts_401(ReturnedValue).
auth_return_value_is_bad_http_response_ts(ReturnedValue) :-
    auth_return_value_is_bad_http_response_ts_403(ReturnedValue).
auth_return_value_is_bad_http_response_ts(ReturnedValue) :-
    auth_return_value_is_bad_http_response_ts_404(ReturnedValue).
auth_return_value_is_bad_http_response_ts(ReturnedValue) :-
    auth_return_value_is_bad_http_response_via_1st_party_wrapper(ReturnedValue).
% add more "bad" codes here ...

% -----------------------------------------------------------------------------
% auth_authenticating_function_by_return_values( Callable )
%
% Structural sibling of `auth_authenticating_function_name/1` ( the
% tier-1 NAME catalog above ). Recognises a middleware-guard-shaped
% callable *by the values it returns* : exactly N bad-http returns
% plus exactly 1 "fall-through" return ( the parser-injected `return
% null` anchored at the callable's header location ). That signature
% IS the signature of a guard middleware -- every failing path emits
% an HTTP error, the single success path falls through implicitly.
%
% Design choice -- no `forall/2` :
% -------------------------------
% Instead of one open-ended clause "every non-fall-through return is
% bad", each candidate arity is enumerated as its own clause :
%
%     by_1v1_return_values : 1 bad + 1 fall-through  ( 2 returns total )
%     by_2v1_return_values : 2 bad + 1 fall-through  ( 3 returns total )
%     by_3v1_return_values : 3 bad + 1 fall-through  ( 4 returns total )
%     by_4v1_return_values : 4 bad + 1 fall-through  ( 5 returns total )
%
% Rationale :
%   1. Each shape is a ground rule the demo-driving LLM can inspect
%      verbatim -- no quantifier semantics to reason about.
%   2. The fall-through's position ( `ReturnedValue = Callable` ) is
%      named explicitly per shape instead of being derived post-hoc
%      from a quantifier.
%   3. Debuggability : a misfire on one shape is isolated to that
%      clause.
%   4. Determinism : a K-return callable matches exactly one shape
%      ( the shape whose bad-count = K - 1 ), so query results dedup
%      by construction.
% Cost : O(N) clauses. For N = 4 that is four short clauses ;
% extension to higher arities is a pure leaf addition per clause.
%
% Fall-through convention ( set by the parser ) :
% ----------------------------------------------
%     Every callable body has a `return null` synthetically appended,
%     whose ReturnedValue location coincides with the callable's
%     header location. In Prolog that means
%     `kb_callable_returns_value( F, F )` for exactly one return of
%     every well-formed callable. See
%     `TsParserActions.hs::ensureCallableBodyEndsWithReturn` for the
%     injection.
%
% Bare `return;` cardinality gate :
% --------------------------------
%     `kb_callable_returns_without_value( F, _ )` must be empty. Bare
%     returns are semantically equivalent to fall-throughs but break
%     the clean "N-bad + 1-fall-through" count. Guards that mix bare
%     and value returns are rare in practice ; leaf-add a dedicated
%     shape family here if a real-world case demands it.

auth_authenticating_function_by_return_values(F) :-
    auth_authenticating_function_by_1v1_return_values(F).
auth_authenticating_function_by_return_values(F) :-
    auth_authenticating_function_by_2v1_return_values(F).
auth_authenticating_function_by_return_values(F) :-
    auth_authenticating_function_by_3v1_return_values(F).
auth_authenticating_function_by_return_values(F) :-
    auth_authenticating_function_by_4v1_return_values(F).
% add more shape arities here ( by_5v1_return_values, by_6v1_return_values, ... ) ...

% Enumeration idiom -- `kb_callable_returns_value(F, F)` :
% ------------------------------------------------------
% Every clause below opens with `kb_callable_returns_value(F, F)`.
% That is NOT decorative -- it is what enumerates F over callables
% when the caller queries the shape predicate with F unbound ( eg
% `findall(F, auth_authenticating_function_by_return_values(F), _)` ).
%
% Without this leading goal, the subsequent
% `findall(R, kb_callable_returns_value(F, R), Returns)` would fire
% with an UNBOUND F -- Prolog's `findall/3` unifies R against every
% `kb_callable_returns_value(_, _)` fact in the KB, producing a
% single giant list mixed across ALL callables and never hitting the
% `length(Returns, K)` cardinality gate.
%
% `kb_callable_returns_value(F, F)` uses the parser-injected
% fall-through as the enumerator : every well-formed callable body
% has exactly one such fact where the ReturnedValue location
% coincides with the callable's own header location ( see
% `TsParserActions.hs::ensureCallableBodyEndsWithReturn` ). One fact
% per callable means F is enumerated ONCE per candidate -- no
% duplicate shape checks. Callables that lack a fall-through ( eg an
% AST that never went through `ensureCallableBodyEndsWithReturn` )
% are correctly excluded here : the shape predicate is only sound
% under the fall-through convention anyway.

% 1v1 : exactly 2 value-returns -- one is a bad-http response, the
% other is the parser-injected fall-through ( `ReturnedValue =
% Callable` ). No bare returns anywhere in the body.
auth_authenticating_function_by_1v1_return_values(F) :-
    kb_callable_returns_value(F, F),
    findall(R, kb_callable_returns_value(F, R), Returns),
    length(Returns, 2),
    \+ kb_callable_returns_without_value(F, _),
    select(F, Returns, [Bad1]),
    auth_return_value_is_bad_http_response(Bad1).

% 2v1 : exactly 3 value-returns -- two are bad-http responses, one is
% the parser-injected fall-through. No bare returns.
auth_authenticating_function_by_2v1_return_values(F) :-
    kb_callable_returns_value(F, F),
    findall(R, kb_callable_returns_value(F, R), Returns),
    length(Returns, 3),
    \+ kb_callable_returns_without_value(F, _),
    select(F, Returns, [Bad1, Bad2]),
    auth_return_value_is_bad_http_response(Bad1),
    auth_return_value_is_bad_http_response(Bad2).

% 3v1 : exactly 4 value-returns -- three are bad-http responses, one
% is the parser-injected fall-through. No bare returns.
auth_authenticating_function_by_3v1_return_values(F) :-
    kb_callable_returns_value(F, F),
    findall(R, kb_callable_returns_value(F, R), Returns),
    length(Returns, 4),
    \+ kb_callable_returns_without_value(F, _),
    select(F, Returns, [Bad1, Bad2, Bad3]),
    auth_return_value_is_bad_http_response(Bad1),
    auth_return_value_is_bad_http_response(Bad2),
    auth_return_value_is_bad_http_response(Bad3).

% 4v1 : exactly 5 value-returns -- four are bad-http responses, one
% is the parser-injected fall-through. No bare returns.
auth_authenticating_function_by_4v1_return_values(F) :-
    kb_callable_returns_value(F, F),
    findall(R, kb_callable_returns_value(F, R), Returns),
    length(Returns, 5),
    \+ kb_callable_returns_without_value(F, _),
    select(F, Returns, [Bad1, Bad2, Bad3, Bad4]),
    auth_return_value_is_bad_http_response(Bad1),
    auth_return_value_is_bad_http_response(Bad2),
    auth_return_value_is_bad_http_response(Bad3),
    auth_return_value_is_bad_http_response(Bad4).

% -----------------------------------------------------------------------------
% auth_capability_verifier( Callable )
%
% Recognises "capability verifier" callables : functions that consume
% a payload plus a signature ( HMAC / JWT / ... ), recompute the
% expected signature from a shared secret, compare, and return a
% boolean-ish verdict. When another endpoint hands the request off to
% this verifier ( eg the H2 endpoint in the formbricks demo ), the
% verifier IS the authentication gate for that route and H2 should
% NOT be surfaced as an independently-discoverable endpoint. See
% `demo/formbricks.md`.
%
% Two-tier layout mirrors `auth_authenticating_function` :
%
%   tier-1 : name catalog  ( `auth_capability_verifier_name/1` ;
%            empty by design )
%   tier-2 : structural gate  ( `auth_capability_verifier_by_shape/1` )
%
% Both tiers are pure leaf additions -- adding a name or a new crypto
% leaf never forces any existing clause to change.

auth_capability_verifier(Callable) :-
    auth_capability_verifier_by_name(Callable).
auth_capability_verifier(Callable) :-
    auth_capability_verifier_by_shape(Callable).
% add more capability-verifier tiers here ...

auth_capability_verifier_by_name(Callable) :-
    kb_func_def(Callable, Name, _, _),
    auth_capability_verifier_name(Name).

% -----------------------------------------------------------------------------
% auth_capability_verifier_by_shape( Callable )
%
% Structural detector. Fires when `Callable`'s body contains :
%
%   (a) a call to a tier-1 crypto leaf ( HMAC digest / JWT verify /
%       timingSafeEqual / ... -- see `auth_crypto_leaf_call/1` in
%       predicates/auth/nodejs/native.pl ) ;
%
%   (b) an early-return guard on an equality / inequality comparison
%       ( `kb_gated_return_on_comparison/4`, defined below on top of
%       the primitive `kb_gated_return` + `kb_comparison` facts ) ;
%
%   (c) intra-procedural dataflow from the crypto leaf call to one
%       side of the comparison ( symmetric : lhs OR rhs qualifies ).
%
% The operator slot ( Op ) is deliberately left unbound : both @==@
% ( return-false-on-mismatch ) and @!=@ ( return-false-on-mismatch
% with inverted condition ) are valid capability-verifier shapes.

auth_capability_verifier_by_shape(Callable) :-
    kb_called_from(CryptoCall, Callable),
    auth_crypto_leaf_call(CryptoCall),
    kb_gated_return_on_comparison(Lhs, Rhs, _, _),
    auth_capability_verifier_dataflow_side(CryptoCall, Lhs, Rhs).

auth_capability_verifier_dataflow_side(CryptoCall, Lhs, _) :-
    dataflow_intra_path(CryptoCall, Lhs, _).
auth_capability_verifier_dataflow_side(CryptoCall, _, Rhs) :-
    dataflow_intra_path(CryptoCall, Rhs, _).

% -----------------------------------------------------------------------------
% kb_gated_return_on_comparison( Lhs, Rhs, Op, ReturnedValue )
%
% Recognizes early-return guards whose gating expression is a boolean
% comparison. Composed on top of the two primitive facts :
%
%     kb_gated_return( Cond, ReturnedValue )
%         emitted by kbgen for every gated `if (...) return ...;`.
%
%     kb_comparison( Cond, Lhs, Rhs, Op )
%         emitted by kbgen for every equality / inequality binop ( see
%         the 'Comparison' fact in `dhscanner-kbgen` ). Op is a Prolog
%         atom : `eq` for @==@ / @===@ ; `neq` for @!=@ / @!==@.
%
% The two facts share the same `Cond` slot on purpose : it is the
% location of the comparison's output temporary variable, which is
% exactly the value that ends up feeding the `if`'s assume node.

kb_gated_return_on_comparison(Lhs, Rhs, Op, ReturnedValue) :-
    kb_gated_return(Cond, ReturnedValue),
    kb_comparison(Cond, Lhs, Rhs, Op).

% -----------------------------------------------------------------------------
% auth_reaches_capability_verifier( Callable, Verifier )
%
% Recognises `Callable`s that dispatch to a `Verifier` via a bounded
% 1st-party call chain. Downstream ranking uses this to mark request
% handlers ( in particular POST handlers ) that are capability-gated
% by delegation -- eg the H2 storage POST handler in the formbricks
% demo which is guarded end-to-end by `validateLocalSignedUrl`. Such
% handlers should NOT be surfaced as independently-discoverable
% endpoints ; their reachability is fully mediated by the verifier.
%
% Two enumerated arities mirror the
% `auth_authenticating_function_by_*v1` shape-catalog style ( each
% hop count is a ground rule an LLM can inspect verbatim, no
% `between/3` / recursion ) :
%
%   auth_reaches_capability_verifier_1hop : direct call.
%   auth_reaches_capability_verifier_2hop : one intermediate
%                                           1st-party callable between
%                                           them.
%
% Bounded on purpose : deeper chains are almost always a sign of a
% missing tier-1 name entry ( at which point the direct-name gate
% fires and the hop bound is irrelevant ). Add `_3hop`, `_4hop`, ...
% clauses here as pure leaf additions if a real-world case demands it.
%
% Loop guards :
%
%   Middle    \== Callable  ( 2hop )     -- reject Callable -> Callable -> V
%   Middle    \== Verifier  ( 2hop )     -- reject C -> V -> V ( use 1hop )
%   Callable  \== Verifier  ( both )     -- a verifier that is itself
%                                           a `Callable` is already
%                                           covered by
%                                           `auth_capability_verifier/1`.
%                                           This predicate is strictly
%                                           for delegated capability
%                                           gating.

auth_reaches_capability_verifier(Callable, Verifier) :-
    auth_reaches_capability_verifier_1hop(Callable, Verifier).
auth_reaches_capability_verifier(Callable, Verifier) :-
    auth_reaches_capability_verifier_2hop(Callable, Verifier).
% add more hop-count clauses here ...

auth_reaches_capability_verifier_1hop(Callable, Verifier) :-
    kb_called_from(Call, Callable),
    auth_1st_party_call_to_func(Call, Verifier),
    Callable \== Verifier,
    auth_capability_verifier(Verifier).

auth_reaches_capability_verifier_2hop(Callable, Verifier) :-
    kb_called_from(Call1, Callable),
    auth_1st_party_call_to_func(Call1, Middle),
    Middle \== Callable,
    kb_called_from(Call2, Middle),
    auth_1st_party_call_to_func(Call2, Verifier),
    Middle \== Verifier,
    Callable \== Verifier,
    auth_capability_verifier(Verifier).

% -----------------------------------------------------------------------------
% auth_1st_party_call_to_func( Call, Func )
%
% Small resolver helper : succeeds when `Call` is a call site whose
% callee is a 1st-party callable definition `Func`. Combines both
% resolution modes emitted by kbgen ( defined-in-file /
% defined-in-dir ) into a single predicate so higher-level callers
% don't have to repeat the pair. Kept intentionally near the
% hop-count predicates that consume it -- the two shape-recognizer
% clauses of `auth_authenticating_function/3` above use the same two
% facts inline, on purpose, so the tier-1 name gate stays visible
% right at the call-resolution step ; this helper is for the
% hop-count case where we don't have a name gate to interleave.

auth_1st_party_call_to_func(Call, Func) :-
    kb_call_1st_party_func_defined_in_file(Call, Name, DefFile),
    kb_func_def(Func, Name, DefFile, _).
auth_1st_party_call_to_func(Call, Func) :-
    kb_call_1st_party_func_defined_in_dir(Call, Name, DefDir),
    kb_func_def(Func, Name, _, DefDir).
