-module(pc).
-behaviour(gen_server).
-compile(export_all).
-define(MAIN,'main@asaf-VirtualBox').
-define(N,600).
-define(M,1000).
-define(PC1,'pc1@asaf-VirtualBox').
-define(PC2,'pc2@asaf-VirtualBox').
-define(PC3,'pc3@asaf-VirtualBox').
-define(PC4,'pc4@asaf-VirtualBox').
%    starting the gen server and init it
%---------------------------------------------------------
start_link(Num)->
	gen_server:start_link({local,gs},pc,[Num],[]).	%start gs

%init function, start the ets
init([Num]) ->
	io:format("init: ~p~n",[Num]),
	ets:new(borders,[set,named_table,public]),	    %ets for the borders
	makeBorders(Num),				    %set borders for each PC
	ets:new(location,[set,named_table,public]),	    %for holding the process that will run in my corner
	ets:new(param,[set,named_table,public]),	    %for paramters
	ets:insert(param,{index,Num}),			    %add my number to ets, this number will say which corner in the map i manege
	setBounds(Num),					    %set bounds for each PC
	gen_server:cast({gs,?MAIN},{ready,Num,node()}),	    %send main im ready
	{ok,set}.				            %done

%          --Status--
%function that send the main the status if the pc with the location of all the proesses in this pc
status()->
	receive %wait
	after 50->ok
	end, %end wait
	Location=ets:tab2list(location),		       	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{status,read(param,index),Location}),  	%send the ets with locations to main
	status(). 
%---------------------------------------------------------

%function that check what will be in the next more of process
checkMove({X,_},{Xmin,_},{_,_})when X<Xmin->%left
	[{Check,Tmp}]=ets:lookup(borders,left),{left,Tmp};
checkMove({X,_},{_,Xmax},{_,_})when X>Xmax->%right
	[{Check,Tmp}]=ets:lookup(borders,right),{right,Tmp};
checkMove({_,Y},{_,_},{Ymin,_})when Y<Ymin->%up
	[{Check,Tmp}]=ets:lookup(borders,up),{up,Tmp};
checkMove({_,Y},{_,_},{_,Ymax})when Y>Ymax->%down
	[{Check,Tmp}]=ets:lookup(borders,down),{down,Tmp};
checkMove(_,_,_)->{ok,freespace}.


checkBar(PC,{X,Y})->ok.
	
handle_call({walkreq,Old,New,ProPid},_,ready)->
	io:format("received walkreq~n"),
	[{_Ind,TmpPc}]=ets:lookup(param,index),
	[{_Bounds,{{Xmin,Xmax},{Ymin,Ymax}}}]=ets:lookup(param,bounds),
	{Dir,CrossPC}=checkMove(New,{Xmin,Xmax},{Ymin,Ymax}),

	io:format("~p:~p~n",[Dir,CrossPC]),


	case CrossPC of %reply the process the ack with the details for is requset
		bar->io:format("sent bar to the process~n"),{reply,bar,ready};
		wall->io:format("sent wall to the process~n"),{reply,wall,ready};
		freespace->io:format("sent freespace to the process~n"),
	%update ets
		[{Old,Data}]=ets:lookup(location,Old),
		ets:delete(location,Old),
		ets:insert(location,{New,Data}),
		{reply,ok,ready};
		_->io:format("sent cross to the process~n"),

		case gen_server:call({gs,CrossPC},{cross,Old,Dir,read(param,{ProPid,gender}),read(param,{ProPid,rank})}) of
			ok->ets:delete(location,Old),{reply,cross,ready};%if cross, the process kill himself
			_->{reply,wall,ready}
		end	
	end;

handle_call({cross,{Xold,Yold},Dir,Gender,Rank},_,ready)->
	case Dir of
		up->X=Xold,Y=Yold-1;
		down->X=Xold,Y=Yold+1;
		right->X=Xold+1,Y=Yold;
		left->X=Xold-1,Y=Yold
	end,
	Pid = spawn(pro,start,[{X,Y},Gender,Rank]),
	ets:insert(location,{{X,Y},{Pid,Gender}}),
	io:format("process moved to:{~p,~p}~n",[X,Y]),
	{reply,ok,ready}.

%----kill-state----
terminate(_,_)->
	io:format("pc down~n"),	
	ok.   						% terminate the pc
handle_cast({kill},_)->
	Location=ets:tab2list(location),		        	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{suicide,read(param,index),Location}),  	%send the ets with locations to main
	ets:delete(location),ets:delete(param),				%delete the ets
	{stop,normal,done};						%message reply
						
%-----------------


handle_cast({readyack},set)->
	io:format("connected to main~n"),
	spawn_link(fun()->status() end),
	{noreply,ready};

%from user
handle_cast({new,Gender,{X,Y}},ready)->
	%insert to ets + check close to other process (smell or contact)
	Pid = spawn(pro,start,[{X,Y},Gender,-1]),
	ets:insert(location,{{X,Y},{Pid,Gender}}),
	io:format("new proc: ~p in {~p,~p}~n",[Gender,X,Y]),
	{noreply,ready};


%from other pc
handle_cast({cross,Gender,{X,Y},Rank},ready)->
	
	%insert to ets + check close to other process (smell or contact)
	Pid = spawn(pro,start,[{X,Y},Gender,Rank]),
	ets:insert(location,{{X,Y},{Pid,Gender}}),
	io:format("process moved to:{~p,~p}~n",[X,Y]),
	
	{noreply,ready}.

move(X,Y)->
	[{{X,Y},{Pid,Gender}}]=ets:lookup(location,{X,Y}),
	io:format("sending move~n"),
	Pid!{move}.

% for each pc, set what he see in the board, in the init stage
makeBorders(PC)->
	case PC of
	pc1->ets:insert(borders,[{up,wall},{down,?PC3},{right,?PC2},{left,wall}]);
	pc2->ets:insert(borders,[{up,wall},{down,?PC4},{right,wall},{left,?PC1}]);
	pc3->ets:insert(borders,[{up,?PC1},{down,wall},{right,?PC4},{left,wall}]);
	pc4->ets:insert(borders,[{up,?PC2},{down,wall},{right,wall},{left,?PC3}])
	end.


%set the bounds for each pc at the init stage
setBounds(PC)->
	case PC of
	pc1->ets:insert(param,{bounds,{{1,?M/2},{1,?N/2}}});
	pc2->ets:insert(param,{bounds,{{(?M/2)+1,?M},{1,?N/2}}});
	pc3->ets:insert(param,{bounds,{{1,?M/2},{(?N/2)+1,?N}}});
	pc4->ets:insert(param,{bounds,{{(?M/2)+1,?M},{(?N/2)+1,?N}}})
	end.

%---cross-table---
%cross for pc1
%checkCross1({X,Y})when X=<(?M)/4,Y==0->bar;
%checkCross1({X,Y})when Y=<(?N)/4,X==0->bar;
%checkCross1({X,Y})when Y==0;X==0->wall;
%checkCross1({X,Y})when X>(?M)/2,Y>(?N)/2->pc4;
%checkCross1({_,Y})when Y>(?N)/2->pc3;
%checkCross1({X,_})when X>(?M)/2->pc2;
%checkCross1(_)->freespace.
%cross for pc2
%checkCross2({X,Y})when X>=3*(?M)/4,Y==0->bar;
%checkCross2({X,Y})when Y=<(?N)/4,X==41->bar;
%checkCross2({X,Y})when Y==0;X==?M+1->wall;
%checkCross2({X,Y})when X=<(?M)/2,Y>(?N)/2->pc3;
%checkCross2({_,Y})when Y>(?N)/2->pc4;
%checkCross2({X,_})when X=<(?M)/2->pc1;
%checkCross2(_)->freespace.
%cross for pc3
%checkCross3({X,Y})when X=<(?M)/4,Y==21->bar;
%checkCross3({X,Y})when Y>=3*(?N)/4,X==0->bar;
%checkCross3({X,Y})when Y==?N+1;X==0->wall;
%checkCross3({X,Y})when X>(?M)/2,Y=<(?N)/2->pc2;
%checkCross3({_,Y})when Y=<(?N)/2->pc1;
%checkCross3({X,_})when X>(?M)/2->pc4;
%checkCross3(_)->freespace.
%cross for pc4
%checkCross4({X,Y})when X>=3*(?M)/4,Y==21->bar;
%checkCross4({X,Y})when Y>=3*(?N)/4,X==41->bar;
%checkCross4({X,Y})when Y==?N+1;X==?M+1->wall;
%checkCross4({X,Y})when X=<(?M)/2,Y=<(?N)/2->pc1;
%checkCross4({_,Y})when Y=<(?N)/2->pc2;
%checkCross4({X,_})when X=<(?M)/2->pc3;
%checkCross4(_)->freespace.
%----------------


read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).

kill()->gen_server:stop(gs).

%mapBuild()->
%	receive
%	{0,0}->%bar need to be in (0-10,0-5)
%
%	{0,20}->%bar need to be in (0-10,20-15)
%
%	{10,0}->%bar need to be in (30-40,0-5)
%
%	{10,20}->%bar need to be in (30-40,20-15)
% 	_->error end.

heart(X,Y)->
	spawn(pc,heart,[X,Y,[h1,h2,h3,h4,h5,h6|[]] ]).
heart(X,Y,[])-> ets:delete(location,{X,Y});
heart(X,Y,[H|T])->
	ets:insert(location,{{X,Y},{1,H}}),
	wait(100),
	heart(X,Y,T).

wait(X)->
	receive
		after X-> ok
	end.
