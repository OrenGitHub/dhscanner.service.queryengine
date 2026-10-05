:- style_check(-singleton).

sinks_has_prepared_statement_fqn_golang_gorm(PreparedStatement) :-
    kb_has_fqn(PreparedStatement, 'gorm.io/gorm/clause.OrderByColumn').
