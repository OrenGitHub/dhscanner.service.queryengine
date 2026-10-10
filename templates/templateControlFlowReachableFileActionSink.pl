:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `ControlFlowReachableFileActionSink` kbapi query.
%
% Direct analogue of `templateControlFlowReachableSqlSink.pl` --
% same bounded-closure walk, same template-slot contract, same
% `format("Fqn(~q)~n", [Fqn])` output envelope -- just with a
% different sink-membership predicate.
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
% Membership of an FQN as a file-action sink is done conservatively
% here with substring probes against the three leaves of
% `Content.FileActionKind` ( write / read / delete ). The probes
% catch every file-API shape kbgen is observed to emit on the
% OWASP demo corpus -- native Node.js APIs under both their
% CommonJS ( `fs.<verb>{,Sync}` ) and ESM promises ( `fs/promises.<verb>` /
% `node:fs/promises.<verb>` ) spellings, plus re-exported wrappers
% ( `fs/promises.fs.readFile`, `@acme/io.writeFile`, ... ) that keep
% the verb token in the FQN tail.
%
% Classification into the three `FileActionKind` leaves is done
% Haskell-side on the returned FQNs ; the Prolog layer only decides
% membership. Adding a new file-sink family ( eg a cloud SDK's
% `putObject` ) is a one-line clause addition below + a matching
% tail-check in `classifyKind` on the Haskell side.
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
            is_file_action_sink_fqn(Fqn)
        ),
        FqnsRaw
    ),
    list_to_set(FqnsRaw, Fqns),
    print_matches(Fqns).

% File-action-sink membership across the three `FileActionKind`
% leaves. Substring probes on the KB's emitted FQN -- deliberately
% loose so re-exported wrappers ( eg `fs/promises.fs.writeFile`,
% `@acme/io.writeFile` ) are caught alongside the native APIs.
% Add new families here with a one-line clause ; keep tail checks
% specific enough that benign names ( eg a user-defined
% `.readFileFromCache` helper that only touches memory ) do not
% false-positive.
%
% Write family :
is_file_action_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.writeFile').
is_file_action_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.appendFile').
% Read family :
is_file_action_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.readFile').
% Delete family :
is_file_action_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.unlink').
is_file_action_sink_fqn(Fqn) :- sub_atom(Fqn, _, _, _, '.rmdir').

print_matches([]) :- !.
print_matches([Fqn|Tail]) :-
    format("Fqn(~q)~n", [Fqn]),
    print_matches(Tail).
