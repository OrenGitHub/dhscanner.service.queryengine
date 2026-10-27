:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `SelectControlFlowReachableSinks` kbapi query.
%
% Every call site within a bounded number of hops from the source
% callable whose sink kind is one of the requested ones.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {SOURCE_ATOM}      - the source callable's atom-encoded Location
%   {LIMIT_NUM_HOPS}   - max hops through the one-hop callable edge
%   {SINKS}            - list of sink kinds to keep ( kbapi `Sink` names )
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Output : one JSON list of { location, qualifiedName, kind } objects,
% with `location` the call site's location atom.
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_class_def/3.
:- dynamic kb_method_of_class/2.
:- dynamic kb_method_has_name/2.
:- dynamic kb_call_method_of_class/3.
:- dynamic kb_class_has_1st_party_super/3.
:- dynamic kb_class_has_3rd_party_super/3.
:- dynamic kb_callable_source_body_length/2.
:- dynamic kb_arg_i_for_call/3.
:- dynamic kb_const_string/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Source = '{SOURCE_ATOM}',
    NumHops = {LIMIT_NUM_HOPS},
    Kinds = {SINKS},
    Limit = {LIMIT},
    findnsols(
        Limit,
        _{ location: Call, qualifiedName: Fqn, kind: Kind },
        distinct(Call-Kind, (
            utils_control_flow_reaches_call_bounded(Source, Call, NumHops, [Source]),
            kb_call_resolved(Call, Fqn),
            member(Kind, Kinds),
            sink_kind(Call, Fqn, Kind)
        )),
        Matches
    ),
    !,
    json_write_dict(current_output, Matches, [width(0)]),
    nl.

sink_kind(_, Fqn, 'FileOperationRead') :- sub_atom(Fqn, _, _, _, '.readFile').
sink_kind(Call, _, 'FileOperationRead') :- sinks_arbitrary_file_read(Call).
sink_kind(_, Fqn, 'FileOperationWrite') :- sub_atom(Fqn, _, _, _, '.writeFile').
sink_kind(_, Fqn, 'FileOperationWrite') :- sub_atom(Fqn, _, _, _, '.appendFile').
sink_kind(Call, _, 'FileOperationWrite') :- kb_arg_i_for_call(Arg, _, Call), sinks_arbitrary_file_write(Arg).
sink_kind(_, Fqn, 'FileOperationDelete') :- sub_atom(Fqn, _, _, _, '.unlink').
sink_kind(_, Fqn, 'FileOperationDelete') :- sub_atom(Fqn, _, _, _, '.rmdir').
sink_kind(Call, _, 'FileOperationDelete') :- sinks_arbitrary_file_deletion(Call).
sink_kind(Call, _, 'OpenRedirect') :- sinks_open_redirect(Call).
sink_kind(Call, _, 'SSRF') :- sinks_ssrf(Call).
sink_kind(Call, _, 'SSRF') :- sinks_http_request(Call).
sink_kind(_, Fqn, 'SQL') :- sub_atom(Fqn, _, _, _, '.prisma.').
sink_kind(Call, _, 'SQL') :- sinks_sqli(Call).
