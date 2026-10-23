:- style_check(-singleton).

:- [ 'predicates/sanitizers/error_responses/java/servlet' ].
:- [ 'predicates/sanitizers/error_responses/java/spring' ].

% Not every KB carries these facts ( eg KBs built before kb_gated_call ).
:- dynamic kb_gated_call/3.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_dataflow_edge/2.

% -----------------------------------------------------------------------------
% sanitizers_error_call( Call )
%
% `Call` rejects the request : an error response, from the per-framework
% catalogs under `error_responses/`.

sanitizers_error_call(Call) :- sanitizers_error_call_java_servlet(Call).
sanitizers_error_call(Call) :- sanitizers_error_call_java_spring(Call).

% -----------------------------------------------------------------------------
% sanitizers_branch_guard( Call, UserInput, Cond )
%
% The if-then-else sanitizer gadget : `Cond` is the condition of an `if`
% that guards `Call` against `UserInput` :
%
%   if ( isAllowed( host( url ) ) ) { response.sendRedirect( url ); }
%   else { response.sendError( 400, "Invalid redirect url" ); }
%
%   1. the condition is a call ( `isAllowed` ),
%   2. `UserInput` flows into one of its args,
%   3. one branch holds `Call` ( either branch : polarity is ignored ),
%   4. the other branch holds an error call.

sanitizers_branch_guard(Call, UserInput, Cond) :-
    kb_gated_call(Cond, Call, Branch),
    once(sanitizers_condition_checks_input(Cond, UserInput, _, _, _, _)),
    once(sanitizers_error_on_other_branch(Cond, Branch, _)).

% -----------------------------------------------------------------------------
% sanitizers_condition_checks_input( Cond, UserInput, CondCall, CondFqn, ArgIndex, Path )
%
% The condition `Cond` is the call `CondCall` ( resolved to `CondFqn` ),
% and `UserInput` flows into its arg number `ArgIndex` along `Path`
% ( a list of locations, `UserInput` first, the arg last ).

sanitizers_condition_checks_input(Cond, UserInput, CondCall, CondFqn, ArgIndex, Path) :-
    sanitizers_condition_call(Cond, CondCall),
    kb_call_resolved(CondCall, CondFqn),
    kb_arg_i_for_call(Arg, ArgIndex, CondCall),
    sanitizers_flows_into(UserInput, Arg, Path).

% The condition is the call itself ( `if ( check( x ) )` ), or a value
% computed by a call one dataflow edge away ( `ok = check( x ) ; if ( ok )` ).
sanitizers_condition_call(Cond, Cond) :-
    kb_call_resolved(Cond, _).
sanitizers_condition_call(Cond, Call) :-
    \+ kb_call_resolved(Cond, _),
    kb_dataflow_edge(Call, Cond),
    kb_call_resolved(Call, _).

sanitizers_flows_into(UserInput, UserInput, [UserInput]).
sanitizers_flows_into(UserInput, Arg, [UserInput|Rest]) :-
    UserInput \== Arg,
    dataflow_intra_path(UserInput, Arg, Edges),
    findall(Node, member((_, Node), Edges), Rest).

% -----------------------------------------------------------------------------
% sanitizers_error_on_other_branch( Cond, Branch, ErrorCall )
%
% `ErrorCall` is an error call on the branch of `Cond` other than `Branch`.

sanitizers_error_on_other_branch(Cond, Branch, ErrorCall) :-
    kb_gated_call(Cond, ErrorCall, OtherBranch),
    OtherBranch \== Branch,
    sanitizers_error_call(ErrorCall).
