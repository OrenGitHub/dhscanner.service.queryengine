:- style_check(-singleton).

:- [ 'predicates/sanitizers/error_responses/java/servlet' ].
:- [ 'predicates/sanitizers/error_responses/java/spring' ].

% Not every KB carries these facts ( eg KBs built before kbgen 2.3.0 ).
:- dynamic kb_top_level_if_then_else_gadget/4.
:- dynamic kb_call_guarded_by_cond_in_then_part/3.
:- dynamic kb_call_guarded_by_cond_in_else_part/3.
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
% sanitizers_top_level_if_then_else( Call, Cond, ThenPart, ElsePart )
%
% `Call` sits in the then or else part of a top level if-then-else :
%
%   if ( isAllowed( host( url ) ) ) { response.sendRedirect( url ); }
%   else { response.sendError( 400, "Invalid redirect url" ); }

sanitizers_top_level_if_then_else(Call, Cond, ThenPart, ElsePart) :-
    kb_top_level_if_then_else_gadget(_, Cond, ThenPart, ElsePart),
    (   kb_call_guarded_by_cond_in_then_part(Call, Cond, ThenPart)
    ;   kb_call_guarded_by_cond_in_else_part(Call, Cond, ElsePart)
    ).

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
