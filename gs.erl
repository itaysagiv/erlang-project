-module(gs).
-behaviour(gen_server).
-compile(export_all).
-define(PCS,4).
-define(N,424).
-define(M,944).

%-------------------------------------
start_link()->
	gen_server:start_link({local,gs},gs,[],[]).

init(_)->
	%start_board(?N,?M),
	spawn_link(demo,start,[]),				%set up the graphics
	ets:new(pc,[set,named_table,public]),			%set ets to save pcs
	ets:new(param,[set,named_table,public]),		%set ets to save the paramters
	ets:insert(param,{light,lightoff}),			
	ets:new(location,[set,named_table,public]),		%set ets to save locations
	ets:insert(location,[{pc1,[]},{pc2,[]},{pc3,[]},{pc4,[]}]),
	ets:insert(param,{connect_cnt,0}),
	spawn_link(fun()->wait(50000),gen_server:cast(gs,{timeout}) end), %set timer to 5 sec - if not all 4 pcs connect - shut down
	{ok,set}.
%------------------------------------

%sends acks to all pc that connected so they start send status
sendacks(0)->	io:format("all acks sent~n"),spawn_link(fun()->loop() end);
sendacks(N)->
	case N of	%for each pc
		1->	[{pc1,Dest}]=ets:lookup(pc,pc1), gen_server:cast(Dest,{readyack});
		2->	[{pc2,Dest}]=ets:lookup(pc,pc2), gen_server:cast(Dest,{readyack});	
		3->	[{pc3,Dest}]=ets:lookup(pc,pc3), gen_server:cast(Dest,{readyack});		
		4->	[{pc4,Dest}]=ets:lookup(pc,pc4), gen_server:cast(Dest,{readyack})
	end,
	sendacks(N-1).

%wait for all 4 pc to connect
handle_cast({ready,I,Node},set)->
	ets:insert(pc,{I,{gs,Node}}), %save connected pc to ets
	
	%increment counter
	[{connect_cnt,Tmp}]=ets:lookup(param,connect_cnt),
	ets:insert(param,{connect_cnt,Tmp+1}),

	io:format("~p connected~n",[I]),
	io:format("~p pcs are connected so far~n",[Tmp+1]),

	%if 4 pcs connected go to ready
	case Tmp+1==?PCS of
		false->	{noreply,set};
		true->	sendacks(?PCS),{noreply,ready} %all pcs are connected
	end;

%handles the time out in the setting
handle_cast({timeout},set)->
	gen_server:cast(gs,{kill}),
	{noreply,error};
handle_cast({timeout},State)->
	{noreply,State};
handle_cast({kill},_)->
	{stop,normal,done};
handle_cast({status,Index,Grid},ready)->
	%reset(Index),
	%[case Gender of male-> change(X,Y,$X); female-> change(X,Y,$O) end||{{X,Y},{_,Gender}}<-Grid],
	ets:insert(location,{Index,Grid}),
	{noreply,ready}.

terminate(_,_)->
	io:format("server down~n"),
	ok.	

%------------------------------------------------------
%-------------------UI --------------------------------
%------------------------------------------------------
create()-> X=rand:uniform(?M),Y=rand:uniform(?N),case rand:uniform(2) of
1->G=male;
_->G=female end, create(G,X,Y).

create(Gender,X,Y) when X<?M/2 , Y<?N/2->	[{pc1,From}]=ets:lookup(pc,pc1), gen_server:cast(From,{new,Gender,{X,Y}});	
create(Gender,X,Y) when X>=?M/2 , Y<?N/2->	[{pc2,From}]=ets:lookup(pc,pc2), gen_server:cast(From,{new,Gender,{X,Y}});
create(Gender,X,Y) when X<?M/2 , Y>=?N/2->	[{pc3,From}]=ets:lookup(pc,pc3), gen_server:cast(From,{new,Gender,{X,Y}});
create(Gender,X,Y) when X>=?M/2 , Y>=?N/2->	[{pc4,From}]=ets:lookup(pc,pc4), gen_server:cast(From,{new,Gender,{X,Y}}).

%------------------------------------------------------
%-------------GRAPHICS --------------------------------
%------------------------------------------------------

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

start_board(N,M)->
	ets:new(db,[set,named_table]),
	ets:insert(db,{board,init_board(N,M)}),
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

reset(Index)->
	[change(X,Y,$ )||{{X,Y},{_,Gender}}<-read(location,Index)].
	

wait(X)->%function that make wait for X time
	receive
		after X-> ok
	end.

kill()->gen_server:stop(gs).%killing the gs with gen server stop

%--function to help handle ets easly--
%-read: reading from the ets easliy with tab and key
%-write: writing from the ets easliy with tab and key
read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.
write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).
%-------------------------------------

loop()->
	receive
		after 100-> ok
	end,
	canvas!{wx,-220,{wx_ref,74,wxButton,[]},[],{wxCommand,command_button_clicked,[],0,0}},
	loop().

%--function for light in the dance floor--
light(Time)->
	light([light1,light2,light3|[]],0,Time*2).
light(_,N,N)->
	ets:insert(param,{light,lightoff});
light([H|T],N,Stop)->
	ets:insert(param,{light,H}),
	wait(500),
%------------------------------------------
	light(T++[H],N+1,Stop).
