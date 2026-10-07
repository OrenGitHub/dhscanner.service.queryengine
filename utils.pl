:- style_check(-singleton).

problems(Path) :- find_intra_procedural_problems_first(Path), !. % 🛑 STOP if this worked !
problems(Path) :- then_look_for_inter_procedural_prblems(Path).

%find_intra_procedural_problems_first(Path) :- owasp_top_10_intra(Path).
%find_intra_procedural_problems_first(Path) :- arbitrary_file_write_intra(Path).
%find_intra_procedural_problems_first(Path) :- unsafe_deserialization_intra(Path).
%find_intra_procedural_problems_first(Path) :- arbitrary_file_deletion_intra(Path).
find_intra_procedural_problems_first(Path) :- open_redirect_intra(Path).
find_intra_procedural_problems_first(Path) :- arbitrary_file_read_intra(Path).

owasp_top_10_intra(Path) :- injection_intra(Path).
owasp_top_10_intra(Path) :- ssrf_intra(Path).

injection_intra(Path) :- rce_intra(Path).
injection_intra(Path) :- sqli_intra(Path).

rce_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_cmd_exec(Call),
    dataflow_intra_path(UserInput, Call, Path).

sqli_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_sqli(Call),
    dataflow_intra_path(UserInput, Call, Path).

ssrf_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_ssrf(Call),
    dataflow_intra_path(UserInput, Call, Path).

arbitrary_file_read_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_read(Call),
    dataflow_intra_path(UserInput, Call, Path).

unsafe_deserialization_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_unsafe_deserialization(Call),
    dataflow_intra_path(UserInput, Call, Path).

arbitrary_file_deletion_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_deletion(Call),
    dataflow_intra_path(UserInput, Call, Path).

open_redirect_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_open_redirect(Call),
    dataflow_intra_path(UserInput, Call, Path).

endswith(StringInput, StringSuffix) :- atom_concat(_, StringSuffix, StringInput).

then_look_for_inter_procedural_prblems(Path) :- owasp_top_10(Path).

owasp_top_10(Path) :- ssrf(Path).
owasp_top_10(Path) :- arbitrary_file_write(Path).

injection(Path) :- rce(Path).
injection(Path) :- sqli(Path).

ssrf(Path) :-
    sinks_http_request(Call),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

arbitrary_file_write(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_write(Arg),
    dataflow_inter_path(UserInput, Arg, Path).

rce(Path) :-
    endpoints_user_input(UserInput),
    sinks_cmd_exec(Call),
    dataflow_inter_path(UserInput, Call, Path).

sqli(Path) :- sqli_php(Path).

sqli_php(Path) :- sqli_php_yii(Path).

sqli_php_yii(Path) :-
    sinks_sqli_php_yii(Call),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

user_input_might_be_assigned_to(Fqn, Path) :-
    kb_has_fqn(Target, Fqn),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Target, Path).

user_input_might_reach_function(Fqn, Path) :-
    kb_call_resolved(Call, Fqn),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

utils_url_flows_to_return_value(URLCall, Callable, ReturnedValue) :-
    kb_call_resolved(URLCall, 'nodejs.URL'),
    kb_called_from(URLCall, Callable),
    kb_callable_returns_value(Callable, ReturnedValue),
    dataflow_bounded_intra_path(URLCall, ReturnedValue, 5, [URLCall], _).

% ------------------------------------------------------------------
% Bounded call-graph closure : "does control flow reach Fqn from
% Source ?" where Source is any callable location atom ( eg an HTTP
% endpoint handler ) and Fqn is any resolved callee name atom ( eg
% a `kb_call_resolved` sink target like
% `@formbricks/database.prisma.contact.findMany` ).
%
% Three one-hop callable-to-callable edges are modeled, matching
% the three ways the existing KB resolves a call out of a callable's
% body :
%
%   (1) same-dir 1st-party call
%       : `kb_call_1st_party_func_defined_in_dir/3`
%       + `kb_func_def/4` matching the dir slot.
%
%   (2) same-file 1st-party call ( cross-file re-export shape )
%       : `kb_call_1st_party_func_defined_in_file/3`
%       + `kb_func_def/4` matching the file slot. This is what
%         fires for the OWASP demo PUT /contacts/bulk -> upsert
%         BulkContacts cross-file edge ( route.ts line 63 ->
%         bulk/lib/contact.ts line 9 ).
%
%   (3) HOC-wrapper -> inner-handler unwrap ( nextjs-specific )
%       : `endpoints_hoc_dict_handler_unwrap_nextjs/2`. This is
%         what lets the walk descend from the EXPORTED `PUT` ( which
%         has source-body-length = 1 and does nothing but call the
%         HOC like `authenticatedApiClient({ handler : <lambda> })` )
%         INTO the inner lambda where the real request-processing
%         logic ( and the Prisma calls ) live.
%
% Base case is the direct terminal : a call site inside Source
% whose `kb_call_resolved` payload IS the Fqn we are hunting. This
% fires at every recursion depth, so intermediate FQNs are not
% missed.
%
% Depth is bounded at 10 hops ( same budget as the existing
% `dataflow_intra_path/3` ). `Visited` prevents infinite recursion
% on mutual-recursion cycles in the call graph.
%
% No cut is used on either clause ; downstream findall/setof at
% the call site enumerates the full set of reachable FQNs.
%
% Returned FQN is just the raw `kb_call_resolved` atom -- it may
% be a sink ( `@prisma/client.PrismaClient.$queryRaw` ), a parser
% instrumentation leaf ( `<dhscanner-instrumentation>[kv]` ), or
% any other FQN kbgen chose to emit. Callers filter per use case
% ( eg the OWASP-IL 2026 regression step filters to the Prisma
% family via `sub_atom/5` on the `@formbricks/database.prisma.`
% prefix ).
% ------------------------------------------------------------------

utils_control_flow_reaches_sink_fqn(Source, Fqn) :-
    utils_control_flow_reaches_sink_fqn_bounded(Source, Fqn, 10, [Source]).

utils_control_flow_reaches_sink_fqn_bounded(Source, Fqn, _, _) :-
    kb_called_from(CallSite, Source),
    kb_call_resolved(CallSite, Fqn).

utils_control_flow_reaches_sink_fqn_bounded(Source, Fqn, N, Visited) :-
    N >= 1,
    utils_control_flow_callable_calls_callable(Source, Mid),
    \+ member(Mid, Visited),
    N_MINUS_1 is N - 1,
    utils_control_flow_reaches_sink_fqn_bounded(Mid, Fqn, N_MINUS_1, [Mid|Visited]).

utils_control_flow_callable_calls_callable(Caller, Callee) :-
    kb_called_from(CallSite, Caller),
    kb_call_1st_party_func_defined_in_file(CallSite, FuncName, FilePath),
    kb_func_def(Callee, FuncName, FilePath, _).

utils_control_flow_callable_calls_callable(Caller, Callee) :-
    kb_called_from(CallSite, Caller),
    kb_call_1st_party_func_defined_in_dir(CallSite, FuncName, DirPath),
    kb_func_def(Callee, FuncName, _, DirPath).

utils_control_flow_callable_calls_callable(Wrapper, Handler) :-
    endpoints_hoc_dict_handler_unwrap_nextjs(Wrapper, Handler).

:- [ 'api' ].
