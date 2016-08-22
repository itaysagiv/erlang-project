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
checkMove({X,Y},_,_)->case ets:lookup(location,{X,Y}) of
	[]->{ok,freespace};
	_->{ok,person}
end.


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
		person->io:format("sent person to the process~n"),{reply,person,ready};
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
%cross call, when process want to move to other pc. the pc check if he can, if so, he create him
%in his pc location.
handle_call({cross,{Xold,Yold},Dir,Gender,Rank},_,ready)->
	case Dir of 
		up->X=Xold,Y=Yold-1;
		down->X=Xold,Y=Yold+1;
		right->X=Xold+1,Y=Yold;
		left->X=Xold-1,Y=Yold
	end,
	case ets:lookup(location,{X,Y}) of
		[]->Pid = spawn(pro,start,[{X,Y},Gender,Rank]),
		ets:insert(location,{{X,Y},{Pid,Gender}}),
		io:format("process moved to:{~p,~p}~n",[X,Y]),
		{reply,ok,ready};
		_->wait(50),case ets:lookup(location,{X,Y}) of
			[]->Pid = spawn(pro,start,[{X,Y},Gender,Rank]),
			ets:insert(location,{{X,Y},{Pid,Gender}}),
			io:format("process moved to:{~p,~p}~n",[X,Y]),
			{reply,ok,ready};
			_->{reply,dont,ready} 
		end
	end.

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


read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).

kill()->gen_server:stop(gs).



heart(X,Y)->
	spawn(pc,heart,[X,Y,[h1,h2,h3,h4,h5,h6|[]] ]).
heart(X,Y,[])-> ets:delete(location,{X,Y});
heart(X,Y,[H|T])->
	ets:insert(location,{{X,Y},{1,H}}),
	wait(200),
	heart(X,Y,T).

wait(X)->
	receive
		after X-> ok
	end.
