:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `BranchGuardedCall` kbapi query.
%
% Every `if` whose then- or else-branch holds the queried call
% ( `kb_gated_call/3` ), with the calls on the other branch. Polarity is
% ignored : the queried call may sit on either branch.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {CALL_ATOM}        - the guarded call's atom-encoded Location
%   {LIMIT}            - max guards to materialize ( `findnsols` cap )
%
% Output : one JSON list of
%
%   { conditionLocation, conditionQualifiedName,
%     otherBranchCalls : [ { location, qualifiedName, constStringArgs } ] }
%
% with `null` for an unresolved qualified name.
% ------------------------------------------------------------------

:- dynamic kb_gated_call/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_dataflow_edge/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_const_string/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Call = '{CALL_ATOM}',
    Limit = {LIMIT},
    findnsols(Limit, Guard, guard(Call, Guard), Guards),
    !,
    json_write_dict(current_output, Guards, [width(0)]),
    nl.

guard(Call, _{ conditionLocation: Cond, conditionQualifiedName: CondFqn, otherBranchCalls: Others }) :-
    distinct(Cond-Branch, kb_gated_call(Cond, Call, Branch)),
    condition_fqn(Cond, CondFqn),
    (   setof(Other, OtherBranch^(kb_gated_call(Cond, Other, OtherBranch), OtherBranch \== Branch), OtherCalls)
    ->  true
    ;   OtherCalls = []
    ),
    maplist(branch_call, OtherCalls, Others).

% The condition is the call itself ( `if ( check( x ) )` ) or a value
% one dataflow edge away from it.
condition_fqn(Cond, Fqn) :- kb_call_resolved(Cond, Fqn), !.
condition_fqn(Cond, Fqn) :- kb_dataflow_edge(Call, Cond), kb_call_resolved(Call, Fqn), !.
condition_fqn(_, null).

branch_call(Call, _{ location: Call, qualifiedName: Fqn, constStringArgs: Strings }) :-
    (   kb_call_resolved(Call, Resolved) -> Fqn = Resolved ; Fqn = null ),
    findall(Index-String, ( kb_arg_i_for_call(Arg, Index, Call), kb_const_string(Arg, String) ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Strings).
