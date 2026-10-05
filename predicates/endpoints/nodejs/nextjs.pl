:- style_check(-singleton).

% -----------------------------------------------------------------------------
% Next.js HTTP endpoint recognizers (GET / POST / PUT) plus the request
% parameter they expose as a user-input source.

% -----------------------------------------------------------------------------
% endpoints_http_get_nextjs( GetHandler, RequestObject, Url )
%
% The exported `GET` const in a `route.ts` whose first param is a
% request-shaped `NextRequest`.

endpoints_http_get_nextjs(GetHandler, RequestObject, Url) :-
    kb_func_def(GetHandler, 'GET', FileName, Url),
    kb_param_i_of_callable(RequestObject, _, GetHandler),
    kb_param_has_name(RequestObject, 'req'),
    kb_param_has_resolved_type(RequestObject, 'next/server.NextRequest'),
    endswith(FileName, 'route.ts').

% -----------------------------------------------------------------------------
% endpoints_http_post_nextjs( PostHandler, RequestObject, Url )
%
% POST twin of the GET recognizer, with the loosened "request-ish name
% + request-ish resolved type" gate (see the nextjs-local helpers at
% the bottom of this file).

endpoints_http_post_nextjs(PostHandler, RequestObject, Url) :-
    kb_func_def(PostHandler, 'POST', FileName, Url),
    kb_param_i_of_callable(RequestObject, _, PostHandler),
    endpoints_param_has_request_name_nextjs(RequestObject),
    endpoints_param_has_request_resolved_type_nextjs(RequestObject),
    endswith(FileName, 'route.ts').

% -----------------------------------------------------------------------------
% endpoints_http_put_nextjs( PutHandler, RequestObject, Url )
%
% PUT twin of `endpoints_http_post_nextjs/3`. Same structural gate
% ( exported `PUT` in a `route.ts` whose first param is a
% request-shaped `NextRequest` / `nodejs.Request` ) ; only the
% func-def name atom changes from 'POST' to 'PUT'. See the OWASP-IL
% 2026 talk notes ( docs/OWASP26_NOTES.md ) -- the initial verb
% widening to PUT is the prerequisite for the demo's opening-act
% endpoint `PUT /api/v2/management/contacts/bulk` ( notes ss 5.11, 14 ).
%
% Two structural paths bind the PutHandler slot :
%
%   _direct  : the exported `PUT` const IS the handler ( body carries
%              the request-processing logic itself ).
%
%   _wrapper : the exported `PUT` const is a THIN wrapper -- its body
%              is a single call to a higher-order-component ( HOC )
%              like `authenticatedApiClient({ handler: ... })`. The
%              actual PutHandler is the inner lambda unwrapped from
%              the HOC's dict-argument. This is the v2 formbricks
%              shape ; see `endpoints_hoc_dict_handler_unwrap_nextjs/2`
%              at the bottom of this file for the unwrap mechanics +
%              approximation caveats.
%
% Adding further shapes ( decorators, higher-arity HOC configs, ... )
% is a pure leaf addition -- one more clause below, no existing
% clause needs to change.

endpoints_http_put_nextjs(PutHandler, RequestObject, Url) :-
    endpoints_http_put_nextjs_direct(PutHandler, RequestObject, Url).
endpoints_http_put_nextjs(PutHandler, RequestObject, Url) :-
    endpoints_http_put_nextjs_wrapper(PutHandler, RequestObject, Url).
% add more structural paths here ...

endpoints_http_put_nextjs_direct(PutHandler, RequestObject, Url) :-
    kb_func_def(PutHandler, 'PUT', FileName, Url),
    kb_param_i_of_callable(RequestObject, _, PutHandler),
    endpoints_param_has_request_name_nextjs(RequestObject),
    endpoints_param_has_request_resolved_type_nextjs(RequestObject),
    endswith(FileName, 'route.ts').

% Wrapper-style ( v2 ) shape. The exported `PUT` const is a thin
% arrow whose body is a single call to a HOC :
%
%     export const PUT = async (request: NextRequest) =>
%         authenticatedApiClient({
%             handler: async ({ parsedInput, ctx }) => { ... },
%             ...
%         });
%
% `Wrapper` satisfies every gate the direct-shape recognizer imposes
% ( `route.ts`, request-typed first param, ... ) -- so we reuse the
% direct predicate to encode "wrapper looks like a normal handler at
% the top level". Then `endpoints_hoc_dict_handler_unwrap_nextjs/2`
% walks from the wrapper into the HOC's dict-config and binds
% `PutHandler` to the inner lambda.
%
% `RequestObject` stays bound to the WRAPPER's first param ( the
% request-shaped `req` / `request` ) -- kept for symmetry with the
% direct-shape recognizer's output, so the kbapi Match record has a
% stable per-match shape regardless of which structural path bound
% the match. Downstream analyses that trace from RequestObject to
% something inside the handler ( eg dataflow reachability ) will
% naturally land on the wrapper first ; if they need to cross into
% the inner lambda, that is a job for the intra-procedural walker,
% not the recognizer.
endpoints_http_put_nextjs_wrapper(PutHandler, RequestObject, Url) :-
    endpoints_http_put_nextjs_direct(Wrapper, RequestObject, Url),
    endpoints_hoc_dict_handler_unwrap_nextjs(Wrapper, PutHandler).

% -----------------------------------------------------------------------------
% endpoints_user_input_nextjs( Param )
%
% The request parameter of a Next.js handler is itself a user-input
% source : it is the typed entry point for client-supplied data
% ( headers, body, query, ... ).

endpoints_user_input_nextjs(Param) :-
    endpoints_param_has_request_name_nextjs(Param),
    endpoints_param_has_request_resolved_type_nextjs(Param).

% -----------------------------------------------------------------------------
% Nextjs-local helpers.
%
% The request param in Next.js handlers can be named either `req` or
% `request`, and typed either `next/server.NextRequest` or the raw
% `nodejs.Request`. Both tuples are tolerated so the recognizer
% doesn't miss handlers that use the raw nodejs type ( a common
% formbricks pattern ).

endpoints_param_has_request_name_nextjs(Param) :- kb_param_has_name(Param, 'req').
endpoints_param_has_request_name_nextjs(Param) :- kb_param_has_name(Param, 'request').

endpoints_param_has_request_resolved_type_nextjs(Param) :- kb_param_has_resolved_type(Param, 'next/server.NextRequest').
endpoints_param_has_request_resolved_type_nextjs(Param) :- kb_param_has_resolved_type(Param, 'nodejs.Request').

% -----------------------------------------------------------------------------
% endpoints_hoc_dict_handler_unwrap_nextjs( Wrapper, Handler )
%
% Given a thin `Wrapper` callable whose body is a single call to a
% higher-order-component ( HOC ) with an object-literal config,
% bind `Handler` to the inner callable value of some `handler`-style
% kv-pair inside that config.
%
% Semantically this is a syntactic-callable-shape primitive ( not
% endpoint-specific ) ; the only consumer today is
% `endpoints_http_put_nextjs_wrapper/3` above, so it lives here as a
% nextjs-local helper. Promote to `predicates/shapes/` if any
% non-endpoint predicate ever needs the same unwrap.
%
% Structural walk :
%
%     Wrapper           = the outer callable ( eg `export const PUT = async (req) => ...` )
%     OuterCall         = a call in the wrapper's body ( eg `authenticatedApiClient(...)` )
%     DictContent       = arg 0 of OuterCall -- the object literal
%                         `{ handler: <lambda>, ... }`. After ts-parser-actions
%                         instrumentation this lowers to a synthetic call
%                         `dictify(kv(k,v), kv(k,v), ...)`. See
%                         `TsParser.y::exp_dict` and the existing
%                         `auth_ts_response_json_with_status/2`
%                         walker in predicates/auth/nodejs/native.pl
%                         for the pattern.
%     HandlerKV         = one of DictContent's `kv(k, v)` child calls.
%     KeyLoc / KeyName  = arg 0 of HandlerKV -- the const-string key
%                         ( `handler` / `execute` / `run` / ... ) ; we
%                         bind it but do NOT gate on a specific name
%                         so the recognizer stays HOC-name-agnostic
%                         ( OWASP26_NOTES.md ss 14 : "we do NOT catalog
%                         HOC names ; we recognize the outer syntactic
%                         shape only" ).
%     Handler           = arg 1 of HandlerKV -- the value expression.
%                         Positively asserted to be a callable via
%                         `kb_callable_source_body_length/2` with
%                         length >= 1. We cannot use
%                         `kb_param_i_of_callable/3` here : Formbricks
%                         v2 inner handlers are object-destructured
%                         ( `async ({ authentication, parsedInput }) =>
%                         ...` ) and that binding form does not emit
%                         param facts.
%
% Structural gates :
%
%     (1) `kb_callable_source_body_length( Wrapper, 1 )`
%         Source-fidelity gate : the wrapper's source-level
%         [ Ast.Stmt ] body has exactly one statement. Captured at
%         codegen time ( see `Callable.numOriginalSourceInstructions`
%         in the bitcode package and the parser-facing plumbing in
%         `dhscanner.service.codegen/src/CodeGen.hs::handleLambda`,
%         `decFuncToCallable`, `stmtMethodToCallable` ) and preserved
%         through kbgen as the `CallableSourceBodyLength` fact.
%
%         Reasoning at the source level rather than the bitcode level
%         is deliberate : the ts-parser-actions instrumentation lowers
%         a dict-literal HOC argument into a `dictify(kv(...), ...)`
%         call tree, so a single source-level statement typically
%         corresponds to *several* bitcode `Call` instructions. Using
%         a source-level length keeps the recognizer aligned with what
%         the developer actually wrote, independent of how the flat
%         SSA lowering happens to expand the arguments.
%
%     (2) `kb_called_from(OuterCall, Wrapper)`
%         Because `kb_called_from` is outermost-only ( synthetic
%         `dictify` / `kv` calls nested in argument positions never
%         appear here ) and the source body is exactly one statement,
%         this yields exactly one OuterCall solution : the HOC
%         invocation itself.
%
%     (3) `kb_arg_i_for_call(DictContent, 0, OuterCall)`
%         Third slot of `ArgiForCall` is typed `Call` in kbgen ( see
%         `dhscanner.kbgen/src/Kbgen.hs::data ArgiForCall` ), so
%         binding `DictContent` here positively asserts DictContent
%         IS a call location -- the parser-inserted `dictify` call.
%         No separate `kb_call/1` witness is required.
%
%     (4) `kb_callable_source_body_length(Handler, N), N >= 1`
%         Positively asserts Handler IS a callable with a non-empty
%         source body. Object-destructured arrows ( the Formbricks
%         v2 inner-handler shape ) do not emit
%         `kb_param_i_of_callable/3` facts, so that gate would drop
%         every wrapper we actually care about.
endpoints_hoc_dict_handler_unwrap_nextjs(Wrapper, Handler) :-
    kb_callable_source_body_length(Wrapper, 1),
    kb_called_from(OuterCall, Wrapper),
    kb_arg_i_for_call(DictContent, 0, OuterCall),
    kb_arg_i_for_call(HandlerKV, _, DictContent),
    kb_arg_i_for_call(KeyLoc, 0, HandlerKV),
    kb_const_string(KeyLoc, _),
    kb_arg_i_for_call(Handler, 1, HandlerKV),
    kb_callable_source_body_length(Handler, N),
    N >= 1.
