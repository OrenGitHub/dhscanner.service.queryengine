:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `DataFlowPath` kbapi query.
%
% Shortest intra-procedural path first ( iterative deepening up to
% {LIMIT_LENGTH} edges ), then a single inter-procedural hop
% ( `dataflow_inter_path/3` ) as an optional fallback.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {FROM_ATOM}        - source location atom ( eg a user-input param )
%   {TO_ATOM}          - target location atom ( eg a sink call )
%   {LIMIT_LENGTH}     - max intra-procedural path length, in edges
%   {ALLOW_INTER_PROCEDURAL} - `true` to fall back to the inter-procedural hop, else `fail`
%
% Output : one JSON list of location atoms ( From first, To last ), or
% `null` when there is no path.
% ------------------------------------------------------------------

:- dynamic kb_dataflow_edge/2.
:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_param_i_of_callable/3.
:- dynamic kb_const_string/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(http/json)).

main :-
    From = '{FROM_ATOM}',
    To = '{TO_ATOM}',
    MaxLength = {LIMIT_LENGTH},
    (   path(From, To, MaxLength, Edges)
    ->  findall(Node, member((_, Node), Edges), Rest),
        json_write(current_output, [From|Rest], [width(0)])
    ;   json_write(current_output, null)
    ),
    nl.

path(From, To, MaxLength, Edges) :-
    between(1, MaxLength, N),
    dataflow_bounded_intra_path(From, To, N, [From], Edges),
    !.
path(From, To, _, Edges) :-
    {ALLOW_INTER_PROCEDURAL},
    dataflow_inter_path(From, To, Edges),
    !.
