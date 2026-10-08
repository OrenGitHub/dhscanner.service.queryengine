:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `ControlFlowReachableSqlSink` kbapi query.
%
% Takes a caller-supplied source `Location` and enumerates the set
% of SQL sink FQNs that are control-flow-reachable from that
% callable, via `utils_control_flow_reaches_sink_fqn_bounded/4`
% ( see `utils.pl` for the full three-edge closure design ).
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {SOURCE_ATOM}      - the source callable's atom-encoded Location
%                        ( `Kbgen.locationify` output : exactly the
%                        same atom key `kb_func_def/4` uses )
%   {LIMIT_NUM_HOPS}   - max hops through the one-hop callable edge
%                        passed verbatim to the bounded closure
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Classification of an FQN as a SQL sink is done conservatively
% here with a substring probe for `.prisma.` -- this catches both
% the raw `@prisma/client.PrismaClient.$...Raw*` family AND
% re-exported variants a project may expose
% ( eg `@formbricks/database.prisma.contact.findMany` ).
%
% The structural `SqlRaw` vs `SqlPreparedStatement` split is
% performed Haskell-side on the returned FQNs ; the Prolog layer
% only decides membership. This keeps the template deliberately
% small -- adding a new sink family ( `.sqlalchemy.`, `.gorm.`,
% ... ) is a one-line clause addition below.
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_callable_source_body_length/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_const_string/2.

:- set_prolog_flag(character_escapes, false).
:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).

main :-
    Source = '{SOURCE_ATOM}',
    NumHops = {LIMIT_NUM_HOPS},
    Limit = {LIMIT},
    findnsols(
        Limit,
        Fqn,
        (
            utils_control_flow_reaches_sink_fqn_bounded(Source, Fqn, NumHops, [Source]),
            is_sql_sink_fqn(Fqn)
        ),
        FqnsRaw
    ),
    list_to_set(FqnsRaw, Fqns),
    print_matches(Fqns).

% First-cut SQL-sink membership. Pattern-matches on the KB's
% emitted FQN prefix. Add new families here with a one-line clause.
is_sql_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.prisma.').

print_matches([]) :- !.
print_matches([Fqn|Tail]) :-
    format("Fqn(~q)~n", [Fqn]),
    print_matches(Tail).
