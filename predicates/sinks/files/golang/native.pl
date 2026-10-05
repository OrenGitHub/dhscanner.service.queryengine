:- style_check(-singleton).

sinks_arbitrary_file_deletion_golang(Call) :-
    kb_call_resolved(Call, 'os.Remove').
