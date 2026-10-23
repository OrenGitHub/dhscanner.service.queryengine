:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `BranchGuardedCall` kbapi query.
%
% Every `if` that guards the queried call against the user input with
% the if-then-else sanitizer gadget ( `sanitizers_branch_guard/3` in
% `predicates/sanitizers/api.pl` ) : the condition is a call, the user
% input flows into one of its args, one branch holds the queried call
% and the other branch holds an error call.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {CALL_ATOM}        - the guarded call's atom-encoded Location
%   {USER_INPUT_ATOM}  - the user input's atom-encoded Location
%   {LIMIT}            - max guards to materialize ( `findnsols` cap )
%
% Output : one JSON list of
%
%   { conditionLocation, conditionQualifiedName,
%     userInputArgIndex, userInputFlow : [ { location, qualifiedName } ],
%     errorCalls : [ call ], otherBranchCalls : [ call ] }
%
% with call = { location, qualifiedName, constStringArgs } and `null`
% for an unresolved qualified name.
% ------------------------------------------------------------------

:- dynamic kb_gated_call/3.
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
    Call = '{CALL_ATOM}',
    UserInput = '{USER_INPUT_ATOM}',
    Limit = {LIMIT},
    findnsols(Limit, Guard, guard(Call, UserInput, Guard), Guards),
    !,
    json_write_dict(current_output, Guards, [width(0)]),
    nl.

guard(Call, UserInput, _{
    conditionLocation: Cond,
    conditionQualifiedName: CondFqn,
    userInputArgIndex: ArgIndex,
    userInputFlow: Flow,
    errorCalls: Errors,
    otherBranchCalls: Others
}) :-
    distinct(Cond-Branch, kb_gated_call(Cond, Call, Branch)),
    once(sanitizers_condition_checks_input(Cond, UserInput, _, CondFqn, ArgIndex, Path)),
    maplist(flow_step, Path, Flow),
    setof(ErrorCall, sanitizers_error_on_other_branch(Cond, Branch, ErrorCall), ErrorCalls),
    (   setof(Other, OtherBranch^(
            kb_gated_call(Cond, Other, OtherBranch),
            OtherBranch \== Branch,
            \+ memberchk(Other, ErrorCalls)
        ), OtherCalls)
    ->  true
    ;   OtherCalls = []
    ),
    maplist(branch_call, ErrorCalls, Errors),
    maplist(branch_call, OtherCalls, Others).

flow_step(Location, _{ location: Location, qualifiedName: Fqn }) :-
    (   kb_call_resolved(Location, Resolved) -> Fqn = Resolved ; Fqn = null ).

branch_call(Call, _{ location: Call, qualifiedName: Fqn, constStringArgs: Strings }) :-
    (   kb_call_resolved(Call, Resolved) -> Fqn = Resolved ; Fqn = null ),
    findall(Index-String, ( kb_arg_i_for_call(Arg, Index, Call), kb_const_string(Arg, String) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Strings).
