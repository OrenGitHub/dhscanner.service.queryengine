:- style_check(-singleton).

problems(Path) :- find_intra_procedural_problems_first(Path), !. % 🛑 STOP if this worked !
problems(Path) :- then_look_for_inter_procedural_prblems(Path).

%find_intra_procedural_problems_first(Path) :- owasp_top_10_intra(Path).
%find_intra_procedural_problems_first(Path) :- arbitrary_file_write_intra(Path).
%find_intra_procedural_problems_first(Path) :- unsafe_deserialization_intra(Path).
%find_intra_procedural_problems_first(Path) :- arbitrary_file_deletion_intra(Path).
find_intra_procedural_problems_first(Path) :- open_redirect_intra(Path).
find_intra_procedural_problems_first(Path) :- arbitrary_file_read_intra(Path).

owasp_top_10_intra(Path) :- injection_intra(Path).
owasp_top_10_intra(Path) :- ssrf_intra(Path).

injection_intra(Path) :- rce_intra(Path).
injection_intra(Path) :- sqli_intra(Path).

rce_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_cmd_exec(Call),
    dataflow_intra_path(UserInput, Call, Path).

sqli_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_sqli(Call),
    dataflow_intra_path(UserInput, Call, Path).

ssrf_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_ssrf(Call),
    dataflow_intra_path(UserInput, Call, Path).

arbitrary_file_read_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_read(Call),
    dataflow_intra_path(UserInput, Call, Path).

unsafe_deserialization_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_unsafe_deserialization(Call),
    dataflow_intra_path(UserInput, Call, Path).

arbitrary_file_deletion_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_deletion(Call),
    dataflow_intra_path(UserInput, Call, Path).

open_redirect_intra(Path) :-
    endpoints_user_input(UserInput),
    sinks_open_redirect(Call),
    dataflow_intra_path(UserInput, Call, Path).

endswith(StringInput, StringSuffix) :- atom_concat(_, StringSuffix, StringInput).

then_look_for_inter_procedural_prblems(Path) :- owasp_top_10(Path).

owasp_top_10(Path) :- ssrf(Path).
owasp_top_10(Path) :- arbitrary_file_write(Path).

injection(Path) :- rce(Path).
injection(Path) :- sqli(Path).

ssrf(Path) :-
    sinks_http_request(Call),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

arbitrary_file_write(Path) :-
    endpoints_user_input(UserInput),
    sinks_arbitrary_file_write(Arg),
    dataflow_inter_path(UserInput, Arg, Path).

rce(Path) :-
    endpoints_user_input(UserInput),
    sinks_cmd_exec(Call),
    dataflow_inter_path(UserInput, Call, Path).

sqli(Path) :- sqli_php(Path).

sqli_php(Path) :- sqli_php_yii(Path).

sqli_php_yii(Path) :-
    sinks_sqli_php_yii(Call),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

user_input_might_be_assigned_to(Fqn, Path) :-
    kb_has_fqn(Target, Fqn),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Target, Path).

user_input_might_reach_function(Fqn, Path) :-
    kb_call_resolved(Call, Fqn),
    endpoints_user_input(UserInput),
    dataflow_inter_path(UserInput, Call, Path).

utils_url_flows_to_return_value(URLCall, Callable, ReturnedValue) :-
    kb_call_resolved(URLCall, 'nodejs.URL'),
    kb_called_from(URLCall, Callable),
    kb_callable_returns_value(Callable, ReturnedValue),
    dataflow_bounded_intra_path(URLCall, ReturnedValue, 5, [URLCall], _).

:- [ 'api' ].
