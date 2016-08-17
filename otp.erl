-module(otp).
-compile(export_all).

init()->
	register(mypid,self()).	

listen()->
	receive
		{Node,'fuck you'} -> io:format("~p: ~p~n",[Node,'fuck you']),{mypid,Node}!{node(),'thanks, bye'};
		{Node,Msg} -> io:format("~p: ~p~n",[Node,Msg]),{mypid,Node}!{node(),'fuck you'},listen()
	end.

send(Msg,Him)->
	{mypid,Him}!{node(),Msg},
	receive
		{Node,Mes} -> io:format("~p: ~p~n",[Node,Mes])
	end.
