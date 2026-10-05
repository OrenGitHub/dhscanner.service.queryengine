:- style_check(-singleton).

sinks_unsafe_deserialization_ruby(Call) :-
    kb_call_resolved(Call, 'YAML.load_stream').
