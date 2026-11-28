:- style_check(-singleton).

% ------------------------------------------------------------------
% kbapi SelectDBReads
%
% The reads of a column of a 1st party model that an endpoint reaches
% within a bounded number of hops, each with the call sites from the
% endpoint down to the callable that contains the read
% ( `callgraph_reaches_call_bounded_chain/4` ). A read of every column
% ( `'*'` ) is a read of the requested one too.
%
% Slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {ENDPOINT_ATOM}    - location atom of the endpoint ( a handler )
%   {MODEL}            - the model's class name, a quoted atom
%   {COLUMN}           - the column name, a quoted atom
%   {LIMIT_NUM_HOPS}   - max callable to callable hops
%   {LIMIT}            - max number of matches
%
% Output : [ { dbRead, endpointToDBRead } ], location atoms.
% ------------------------------------------------------------------

:- dynamic kb_called_from/2.
:- dynamic kb_called_from_script/2.
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
:- dynamic kb_call_method_of_return_value/3.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'predicates/api' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Endpoint = '{ENDPOINT_ATOM}',
    ModelName = {MODEL},
    Column = {COLUMN},
    NumHops = {LIMIT_NUM_HOPS},
    Limit = {LIMIT},
    findall(ModelClass, kb_class_def(ModelClass, ModelName, _), ModelClasses),
    findnsols(
        Limit,
        _{ dbRead: Read, endpointToDBRead: Chain },
        distinct(Read, (
            callgraph_reaches_call_bounded_chain(Endpoint, Read, NumHops, Chain),
            member(ModelClass, ModelClasses),
            sinks_db_read_column(Read, ModelClass, ReadColumn),
            memberchk(ReadColumn, [Column, '*'])
        )),
        Matches
    ),
    !,
    json_write_dict(current_output, Matches, [width(0)]),
    nl.
