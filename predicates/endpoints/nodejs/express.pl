:- style_check(-singleton).

endpoints_user_input_express(Param) :-
    kb_call_resolved(GetRequestHandler, 'express.Router.route.get'),
    kb_param_has_name(Param, 'req'),
    kb_param_i_of_callable(Param, 0, Lambda),
    kb_arg_i_for_call(Lambda, 0, GetRequestHandler).

sinks_arbitrary_file_read_express_sendFile(Call) :-
    kb_call_resolved(GetRequestHandler, 'express.Router.route.get'),
    kb_call_method_of_untyped_named_param(Call, 'sendFile', Param),
    kb_param_has_name(Param, 'res'),
    kb_arg_i_for_call(Lambda, 0, GetRequestHandler),
    kb_param_i_of_callable(Param, 1, Lambda).
