:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `SelectSanitizers` kbapi query.
%
% Every top level if-then-else whose then or else part holds the sink
% and whose condition is a call the user input flows into
% ( `predicates/sanitizers/api.pl` ).
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {SINK_ATOM}        - the sink call's atom-encoded Location
%   {USER_INPUT_ATOM}  - the user input's atom-encoded Location
%   {LIMIT}            - max gadgets to materialize ( `findnsols` cap )
%
% Output : one JSON list of
%
%   { cond : call, userInputArgIndex,
%     userInputFlow : [ { location, qualifiedName } ],
%     thenPart : [ call ], elsePart : [ call ] }
%
% with call = { location, qualifiedName, constStringArgs } and `null`
% for an unresolved qualified name.
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_dataflow_edge/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_param_i_of_callable/3.
:- dynamic kb_const_string/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Sink = '{SINK_ATOM}',
    UserInput = '{USER_INPUT_ATOM}',
    Limit = {LIMIT},
    findnsols(Limit, Gadget, gadget(Sink, UserInput, Gadget), Gadgets),
    !,
    json_write_dict(current_output, Gadgets, [width(0)]),
    nl.

gadget(Sink, UserInput, _{
    cond: CondCallJson,
    userInputArgIndex: ArgIndex,
    userInputFlow: Flow,
    thenPart: Then,
    elsePart: Else
}) :-
    distinct(Cond, sanitizers_top_level_if_then_else(Sink, Cond, ThenPart, ElsePart)),
    once(sanitizers_condition_checks_input(Cond, UserInput, CondCall, _, ArgIndex, Path)),
    part_call(CondCall, CondCallJson),
    maplist(flow_step, Path, Flow),
    findall(Call, kb_call_guarded_by_cond_in_then_part(Call, Cond, ThenPart), ThenCalls),
    findall(Call, kb_call_guarded_by_cond_in_else_part(Call, Cond, ElsePart), ElseCalls),
    maplist(part_call, ThenCalls, Then),
    maplist(part_call, ElseCalls, Else).

flow_step(Location, _{ location: Location, qualifiedName: Fqn }) :-
    (   kb_call_resolved(Location, Resolved) -> Fqn = Resolved ; Fqn = null ).

part_call(Call, _{ location: Call, qualifiedName: Fqn, constStringArgs: Strings }) :-
    (   kb_call_resolved(Call, Resolved) -> Fqn = Resolved ; Fqn = null ),
    findall(Index-String, ( kb_arg_i_for_call(Arg, Index, Call), kb_const_string(Arg, String) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Strings).
