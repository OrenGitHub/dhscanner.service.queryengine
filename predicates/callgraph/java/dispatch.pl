:- style_check(-singleton).

% -----------------------------------------------------------------------------
% callgraph_java_dispatch( Caller, Callee )
%
% Java method calls whose receiver is a 1st party class ( or interface ) :
%
%   typed call      `groupService.delete( ... )` with `GroupService groupService`
%                   kbgen resolves it to a Haskell-Show atom ( same shape as the
%                   ts one, see `predicates/auth/nodejs/native.pl` ) :
%
%     'FirstPartyImport (FirstPartyImportContent {firstPartyImportedLocation = "<File>", firstPartyImportedName = Just "<Class>"}).<method>'
%
%   unqualified call `returnSitemapFile( ... )` from inside a class
%                   kbgen resolves it to 'Unknown.<method>'
%
% Virtual dispatch : the callee is `<method>` as looked up from the declared
% class and from each of its 1st party subclasses ( `kb_class_has_1st_party_super` ),
% where the lookup takes the nearest definition walking up the supers - so an
% implementation inherited from a base outside the declared class tree counts
% too ( `CollectionDAOImpl.findByLegacyId` lives in `AbstractHibernateDSODAO` ).
% Overloads are not told apart : every method of that name in the nearest
% defining class is a callee.
%
% The 1st party facts exist because the cli maps java imports to repo files
% by their package declaration ( runner #119 ).
% -----------------------------------------------------------------------------

callgraph_java_dispatch(Caller, Callee) :-
    kb_called_from(Call, Caller),
    kb_call_resolved(Call, Fqn),
    callgraph_java_receiver_class(Caller, Fqn, Class, Method),
    callgraph_java_dispatch_class(Class, Dispatched),
    callgraph_java_lookup(Dispatched, Method, Callee).

callgraph_java_receiver_class(_, Fqn, Class, Method) :-
    callgraph_java_first_party_method(Fqn, File, ClassName, Method),
    kb_class_def(Class, ClassName, File).
callgraph_java_receiver_class(Caller, Fqn, Class, Method) :-
    atom_concat('Unknown.', Method, Fqn),
    \+ sub_atom(Method, _, _, _, '.'),
    kb_method_of_class(Caller, Class).

% splits on '"' : [ prefix, File, middle, ClassName, '}).<method>' ]
callgraph_java_first_party_method(Fqn, File, ClassName, Method) :-
    atom_concat('FirstPartyImport (FirstPartyImportContent {', _, Fqn),
    atomic_list_concat([_, File, _, ClassName, Tail], '"', Fqn),
    atom_concat('}).', Method, Tail),
    \+ sub_atom(Method, _, _, _, '.').

:- table callgraph_java_super/2.
callgraph_java_super(Class, Super) :-
    kb_class_has_1st_party_super(Class, SuperName, SuperFile),
    kb_class_def(Super, SuperName, SuperFile).

:- table callgraph_java_dispatch_class/2.
callgraph_java_dispatch_class(Class, Class).
callgraph_java_dispatch_class(Class, Sub) :-
    callgraph_java_super(Mid, Class),
    callgraph_java_dispatch_class(Mid, Sub).

callgraph_java_lookup(Class, Method, Callee) :-
    (   callgraph_java_defines(Class, Method)
    ->  callgraph_java_method_named(Class, Method, Callee)
    ;   callgraph_java_super(Class, Super),
        callgraph_java_lookup(Super, Method, Callee)
    ).

callgraph_java_defines(Class, Method) :-
    callgraph_java_method_named(Class, Method, _),
    !.

callgraph_java_method_named(Class, Method, Callee) :-
    kb_method_of_class(Callee, Class),
    kb_method_has_name(Callee, Method).
