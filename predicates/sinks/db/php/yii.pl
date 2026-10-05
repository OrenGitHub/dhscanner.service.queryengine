:- style_check(-singleton).

sinks_sqli_php_yii(Call) :-
    kb_call_resolved(Call, 'Yii.app.db.createCommand.queryAll').
