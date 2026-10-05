:- style_check(-singleton).

% -----------------------------------------------------------------------------
% endpoints_user_input_tornado( Call )
%
% User-input source : `self.get_query_argument( name )` called on a
% subclass of `tornado.web.RequestHandler`. Two clauses cover direct
% subclassing ( clause 1 ) and 1-hop 1st-party intermediate
% subclassing ( clause 2 ).

endpoints_user_input_tornado(Call) :-
    kb_call_method_of_class(Call, 'get_query_argument', Subclass),
    kb_class_has_3rd_party_super(Subclass, _, 'tornado.web.RequestHandler').

endpoints_user_input_tornado(Call) :-
    kb_call_method_of_class(Call, 'get_query_argument', Subclass),
    kb_class_has_3rd_party_super(Class, _, 'tornado.web.RequestHandler'),
    kb_class_has_1st_party_super(Subclass, ClassName, DefinedInFile),
    kb_class_def(Class, ClassName, DefinedInFile).
