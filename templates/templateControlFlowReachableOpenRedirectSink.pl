:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `ControlFlowReachableOpenRedirectSink` kbapi query.
%
% Same bounded closure as `templateControlFlowReachableFileActionSink.pl`,
% but walks to the reached call sites ( not just their fqns ) so each
% match carries the sink call location. Membership is
% `sinks_open_redirect/1` ( `predicates/sinks/api.pl` ).
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {SOURCE_ATOM}      - the source callable's atom-encoded Location
%   {LIMIT_NUM_HOPS}   - max hops through the one-hop callable edge
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Output : one JSON list of { location, qualifiedName } objects, with
% `location` the call site's location atom.
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_resolved/2.
:- dynamic kb_func_def/4.
:- dynamic kb_class_def/3.
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
    Limit = {LIMIT},
    findnsols(
        Limit,
        _{ location: Call, qualifiedName: Fqn },
        distinct(Call-Fqn, (
            utils_control_flow_reaches_call_bounded(Source, Call, NumHops, [Source]),
            sinks_open_redirect(Call),
            kb_call_resolved(Call, Fqn)
        )),
        Matches
    ),
    !,
    json_write_dict(current_output, Matches, [width(0)]),
    nl.
