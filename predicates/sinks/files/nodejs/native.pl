:- style_check(-singleton).

sinks_arbitrary_file_read_nodejs(Call) :-
    kb_call_resolved(Call, 'fs/promises.readFile').

sinks_arbitrary_file_write_nodejs(Arg) :-
    kb_call_resolved(Call, 'fs/promises.writeFile'),
    kb_arg_i_for_call(Arg, 0, Call).
