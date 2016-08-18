-module(pro).
-compile(export_all).

start({X,Y},Gender)->
	Pid=self(),
	io:format("started process in ~p~n",[Pid]),
	ets:insert(param,{{Pid,curr},{X,Y}}),
	ets:insert(param,{{Pid,gender},Gender}),
	ets:insert(param,{{Pid,rank},rand:uniform(5)+2}),
	loop().

loop()->
	receive
		{move}-> io:format("received move~n"),move()
	end.
move()->
	MoveX = rand:uniform(3)-2,
	MoveY = rand:uniform(3)-2,
	io:format("random: X=~p Y=~p~n",[MoveX,MoveY]),
	Pid=self(),
	[{{Pid,curr},{OldX,OldY}}]=ets:lookup(param,{Pid,curr}),
	case gen_server:call(gs,{walkreq,{OldX,OldY},{OldX+MoveX,OldY+MoveY}}) of
		ok->	io:format("got ok~n"),write(param,{Pid,curr},{OldX+MoveX,OldY+MoveY}),wait(1000),move();
		again->	move()
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
