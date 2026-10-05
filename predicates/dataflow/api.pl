:- style_check(-singleton).

dataflow_intra_path(U, V, Path) :-
    between(1, 10, N),
    dataflow_bounded_intra_path(U, V, N, [U], Path),
    !.

dataflow_bounded_intra_path(A, C, N, _, [(A, C)]) :-
    N >= 1,
    kb_dataflow_edge(A, C).

dataflow_bounded_intra_path(A, C, N, Visited, [(A, B)|Path]) :-
    N >= 2,
    kb_dataflow_edge(A, B),
    \+ member(B, Visited),
    N_MINUS_1 is N - 1,
    dataflow_bounded_intra_path(B, C, N_MINUS_1, [B|Visited], Path).

dataflow_inter_path(U, V, Path) :-
    dataflow_inter_edge(Call, Callee),
    between(1, 10, CallerSideDataflowPathLen),
    between(1, 10, CalleeSideDataflowPathLen),
    dataflow_bounded_intra_path(U, Call, CallerSideDataflowPathLen, [U], CallerSidePath),
    dataflow_bounded_intra_path(Callee, V, CalleeSideDataflowPathLen, [U, Call, Callee], CalleeSidePath),
    \+ member(Callee, [U, Call]),
    append(CallerSidePath, [(Call, Callee)|CalleeSidePath], Path).

dataflow_inter_edge(U, V) :- dataflow_inter_edge_from_arg_to_param(U, V).

dataflow_inter_edge_from_arg_to_param(Arg, Param) :-
    kb_call_1st_party_func_defined_in_dir(Call, FuncName, FuncDefinedInDir),
    kb_func_def(Func, FuncName, _, FuncDefinedInDir),
    kb_arg_i_for_call(Arg, Index, Call),
    kb_param_i_of_callable(Param, Index, Func).

dataflow_inter_edge_from_arg_to_param(Arg, Param) :-
    kb_call_1st_party_func_defined_in_file(Call, FuncName, FuncDefinedInFile),
    kb_func_def(Func, FuncName, FuncDefinedInFile, _),
    kb_arg_i_for_call(Arg, Index, Call),
    kb_param_i_of_callable(Param, Index, Func).
