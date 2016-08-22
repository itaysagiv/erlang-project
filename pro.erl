-module(pro).
-compile(export_all).

start({X,Y},Gender,Rank)->
	Pid=self(),
	io:format("started process in ~p~n",[Pid]),
	ets:insert(param,{{Pid,curr},{X,Y}}),
	ets:insert(param,{{Pid,gender},Gender}),
	case Rank of
	-1 -> ets:insert(param,{{Pid,rank},rand:uniform(5)+2});
	_->ets:insert(param,{{Pid,rank},Rank})
	end,
	move().


move()->
	MoveX = (rand:uniform(3)-2)*3,
	MoveY = (rand:uniform(3)-2)*3,
	io:format("random: X=~p Y=~p~n",[MoveX,MoveY]),
	Pid=self(),
	[{{Pid,curr},{OldX,OldY}}]=ets:lookup(param,{Pid,curr}),
	case gen_server:call(gs,{walkreq,{OldX,OldY},{OldX+MoveX,OldY+MoveY},Pid}) of
		ok->	io:format("got ok~n"),write(param,{Pid,curr},{OldX+MoveX,OldY+MoveY}),wait(100),
		io:format("process ~p now at X=~p Y=~p~n",[Pid,OldX+MoveX,OldY+MoveY]),move();
		bar->write(param,{Pid,curr},{OldX,OldY}),wait(100),move();
		wall->write(param,{Pid,curr},{OldX,OldY}),wait(100),move();
		cross->ok
	end.

read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).

wait(X)->
	receive
		after X-> ok
	end.
