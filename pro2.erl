-module(pro2).
-behaviour(gen_fsm)
-compile(export_all).

start_link({X,Y},Gender,Rank)->
    gen_fsm:start_link({local,pro},pro,[{X,Y},Gender,Rank],[]).

init({X,Y},Gender,Rank)->
	Pid=self(),
	io:format("started process in ~p~n",[Pid]),
	ets:insert(param,{{Pid,curr},{X,Y}}),
	ets:insert(param,{{Pid,gender},Gender}),
	case Rank of
	-1 -> ets:insert(param,{{Pid,rank},rand:uniform(5)+2});
	_->ets:insert(param,{{Pid,rank},Rank})
	end,
	{ok,moving,{X,Y}).
	
