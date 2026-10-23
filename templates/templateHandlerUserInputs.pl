:- style_check(-singleton).

% ------------------------------------------------------------------
% Template for the `HandlerUserInputs` kbapi query.
%
% The params of the handler that `endpoints_user_input/1`
% ( `predicates/endpoints/api.pl` ) recognizes as user input, in param
% order.
%
% Template slots :
%
%   {KNOWLEDGE_BASE}   - path of the kb_XX.pl file to consult
%   {HANDLER_ATOM}     - the handler callable's atom-encoded Location
%   {LIMIT}            - max matches to materialize ( `findnsols` cap )
%
% Output : one JSON list of { location, name } objects.
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
:- dynamic kb_param_has_name/2.
:- dynamic kb_param_i_of_callable/3.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ 'utils.pl' ].
:- use_module(library(solution_sequences)).
:- use_module(library(http/json)).

main :-
    Handler = '{HANDLER_ATOM}',
    Limit = {LIMIT},
    findnsols(
        Limit,
        Index-_{ location: Param, name: Name },
        (
            kb_param_i_of_callable(Param, Index, Handler),
            once(endpoints_user_input(Param)),
            param_name(Param, Name)
        ),
        Pairs
    ),
    !,
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Matches),
    json_write_dict(current_output, Matches, [width(0)]),
    nl.

param_name(Param, Name) :- kb_param_has_name(Param, Name), !.
param_name(_, '').
