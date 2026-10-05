:- style_check(-singleton).

:- [ 'predicates/sinks/files/nodejs/native' ].
:- [ 'predicates/sinks/files/golang/native' ].
:- [ 'predicates/sinks/ssrf/python/requests' ].
:- [ 'predicates/sinks/ssrf/golang/native' ].
:- [ 'predicates/sinks/open_redirects/python/tornado' ].
:- [ 'predicates/sinks/db/php/yii' ].
:- [ 'predicates/sinks/db/golang/gorm' ].
:- [ 'predicates/sinks/rce/golang/native' ].
:- [ 'predicates/sinks/deser/ruby/native' ].

sinks_cmd_exec(Call) :- sinks_cmd_exec_golang(Call).

sinks_sqli(Call) :- sinks_sqli_php_yii(Call).

sinks_ssrf(Call) :- sinks_ssrf_python_requests(Call).

sinks_http_request(Call) :- sinks_http_request_golang(Call).

sinks_arbitrary_file_read(Call) :- sinks_arbitrary_file_read_nodejs(Call).
sinks_arbitrary_file_read(Call) :- sinks_arbitrary_file_read_express_sendFile(Call).

sinks_arbitrary_file_write(Arg) :- sinks_arbitrary_file_write_nodejs(Arg).

sinks_arbitrary_file_deletion(Call) :- sinks_arbitrary_file_deletion_golang(Call).

sinks_open_redirect(Call) :- sinks_open_redirect_python_tornado(Call).

sinks_unsafe_deserialization(Call) :- sinks_unsafe_deserialization_ruby(Call).

sinks_has_prepared_statement_fqn(PreparedStatement) :-
    sinks_has_prepared_statement_fqn_golang_gorm(PreparedStatement).
