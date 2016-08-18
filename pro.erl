-module(pro).
-compile(export_all).

start({X,Y},Gender)->
	ets:new(param,[set,named_table]),
	ets:insert(param,{curr,{X,Y}}),
	ets:insert(param,{gender,Gender}),
	ets:insert(param,{rank,rand:uniform(5)+2}).

move()->
	MoveX = rand:uniform(3)-2,
	MoveY = rand:uniform(3)-2,
	[{curr,{OldX,OldY}}]=ets:lookup(param,curr)
	case gen_server:call(gs,{walkreq,{OldX+MoveX,OldY+MoveY}}) of
		ok->	write(param,curr,{OldX+MoveX,OldY+MoveY}),wait(1000),move();
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
