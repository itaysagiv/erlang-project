-module(board).
-compile(export_all).

print_board(L=[H|_T])->
	io:format("\e[H\e[J"),
	border(length(H)+2),
	inside(L,length(L),length(L)),
	border(length(H)+2).

inside([],0,_)->ok;
inside([H|T],M,S) when M>S/4 , M<(3*S/4)+1-> io:format("*~s*~n",[H]),inside(T,M-1,S);
inside([H|T],M,S) -> io:format("#~s#~n",[H]),inside(T,M-1,S).

border(N)->border(N,N).
border(0,_)->io:format("~n");
border(N,S) when N>(S/4)+1 , N<3*S/4 ->io:format("*"),border(N-1,S);
border(N,S)->io:format("#"),border(N-1,S).

init_board(N,M)->
	init_board(N,M,[],[],M).
init_board(0,0,Board,Line,_)->
	Board++[Line];
init_board(N,0,Board,Line,Save)->
	init_board(N-1,Save,Board++[Line],[],Save);
init_board(N,M,Board,Line,Save)->
	init_board(N,M-1,Board,Line++" ",Save).


start(N,M)->
	ets:new(db,[set,named_table]),
	ets:insert(db,{board,init_board(N,M)}).
	spawn(fun()->loop() end).
	
change(X,Y,C)->
	[{board,B}]=ets:lookup(db,board),
	New = change(B,X,Y,C,[],[]),
	ets:insert(db,{board,New}).

change([],_,_,_,New,_)-> New; %return
change([H|T],0,0,C,New,Line)->	%copy rest of lines
	change(T,0,0,C,New++[H],Line);
change([[]|T],0,1,C,New,Line)-> %insert line to new and go up
	change(T,0,0,C,New++[Line],Line);
change([[H|T1]|T],0,1,C,New,Line)-> %copy letters until end of line
	change([T1|T],0,1,C,New,Line++[H]);
change([[_|T1]|T],1,1,C,New,Line)-> %changing letter
	change([T1|T],0,1,C,New,Line++[C]);
change([[H|T1]|T],X,1,C,New,Line)-> %copy letters until x=1
	change([T1|T],X-1,1,C,New,Line++[H]);
change([H|T],X,Y,C,New,Line)-> %copy lines until y=1
	change(T,X,Y-1,C,New++[H],Line).


loop()->
	receive
		after 100-> ok
	end,
	[{board,B}]=ets:lookup(db,board),
	print_board(B),
	loop().
