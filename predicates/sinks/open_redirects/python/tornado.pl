:- style_check(-singleton).

sinks_open_redirect_python_tornado(Call) :-
    kb_class_has_3rd_party_super(Class, _, 'tornado.web.RequestHandler'),
    kb_call_method_of_class(Call, 'redirect', Class).

sinks_open_redirect_python_tornado(Call) :-
    kb_class_has_3rd_party_super(Class, _, 'tornado.web.RequestHandler'),
    kb_call_method_of_class(Call, 'redirect', Subclass),
    kb_class_has_1st_party_super(Subclass, Name, DefinedInFile),
    kb_class_def(Class, Name, DefinedInFile).
