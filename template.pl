:- style_check(-singleton).

:- discontiguous kb_class_name/2.
:- discontiguous kb_class_def/3.
:- discontiguous kb_subclass_of/2.
:- discontiguous kb_const_string/2.
:- discontiguous kb_param_has_type/2.
:- discontiguous kb_param_has_name/2.
:- discontiguous kb_arg_i_for_call/3.
:- discontiguous kb_method_of_class/2.
:- discontiguous kb_call_resolved/2.
:- discontiguous kb_param_i_of_callable/3.
:- discontiguous kb_class_has_named_super/2.
:- discontiguous kb_class_has_1st_party_super/3.
:- discontiguous kb_class_has_3rd_party_super/3.
:- discontiguous kb_call_method_of_class/3.
:- discontiguous kb_dataflow_edge/2.
:- discontiguous kb_callable_annotated_with/2.
:- discontiguous kb_class_has_resolved_super/2.
:- discontiguous kb_call_method_of_untyped_named_param/3.
:- discontiguous kb_callable_annotated_with_user_input_inside_route/2.
:- discontiguous kb_const_null/1.
:- discontiguous kb_gated_return/2.
:- discontiguous utils_arbitrary_file_write/1.

:- dynamic kb_call_1st_party_func_defined_in_dir/3.
:- dynamic kb_call_1st_party_func_defined_in_file/3.
:- dynamic kb_callable_source_body_length/2.

:- [ '{KNOWLEDGE_BASE}' ].
:- [ '/queryengine/utils' ].

q0(Path0) :- problems(Path0).

queries([
    q0(Path0)
]).

main :-
    queries(QueryList),
    forall(
        member(Query, QueryList),
        (Query -> (write(Query), write(': yes'), nl)); (write(Query), write(': no'), nl)
    ).
