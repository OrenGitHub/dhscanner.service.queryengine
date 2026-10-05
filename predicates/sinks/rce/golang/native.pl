:- style_check(-singleton).

sinks_cmd_exec_golang(Call) :- kb_call_resolved(Call, 'os/exec.CommandContext').
sinks_cmd_exec_golang(Call) :- kb_call_resolved(Call, 'os/exec.Command').
