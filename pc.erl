-module(pc).
-behaviour(gen_server).
-compile(export_all).
-include_lib("stdlib/include/qlc.hrl").
-define(MAIN,'main@asaf-VirtualBox').
-define(N,424).
-define(M,944).
-define(W,28).
-define(H,39).
-define(PC1,'pc1@asaf-VirtualBox').
-define(PC2,'pc2@asaf-VirtualBox').
-define(PC3,'pc3@asaf-VirtualBox').
-define(PC4,'pc4@asaf-VirtualBox').
%    starting the gen server and init it
%---------------------------------------------------------
start_link([Num])->
	gen_server:start_link({local,gs},pc,[Num],[]).	%start gs

%init function, start the ets
init([Num]) ->
	io:format("init: ~p~n",[Num]),
	ets:new(borders,[set,named_table,public]),	    %ets for the borders
	makeBorders(Num),				    %set borders for each PC
	ets:new(location,[set,named_table,public]),	    %for holding the process that will run in my corner
	ets:new(param,[set,named_table,public]),	    %for paramters
	ets:insert(param,{index,Num}),			    %add my number to ets, this number will say which corner in the map i manege
	ets:insert(param,{proc_id,1}),
	ets:insert(param,{light,off}),
	ets:new(interaction,[set,named_table]),
	ets:new(ranks,[set,named_table,public]),
	setBounds(Num),					    %set bounds for each PC
	gen_server:cast({gs,?MAIN},{ready,Num,node()}),	    %send main im ready
	{ok,set}.				            %done

%          --Status--
%function that send the main the status if the pc with the location of all the proesses in this pc
status()->
	receive %wait
	after 50->ok
	end, %end wait
	Location=ets:tab2list(location),
	Ranks = ets:tab2list(ranks),		       	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{status,read(param,index),Location,Ranks}),  	%send the ets with locations to main
	status(). 
%---------------------------------------------------------
checkBar(Tmp,X)->
	case Tmp of
	wallbar-> case X of 
		X when X>?M-396;X<396->bar;
		_->wall
	end;
	_->Tmp
end.

%function that check what will be in the next more of process
checkMove(_,{X,_},{Xmin,_},{_,_},_)when X<Xmin->%left
	[{Check,Tmp}]=ets:lookup(borders,left),{left,checkBar(Tmp,X)};
checkMove(_,{X,_},{_,Xmax},{_,_},_)when X>Xmax->%right
	[{Check,Tmp}]=ets:lookup(borders,right),{right,checkBar(Tmp,X)};
checkMove(_,{X,Y},{_,_},{Ymin,_},_)when Y<Ymin->%up
	[{Check,Tmp}]=ets:lookup(borders,up),{up,checkBar(Tmp,X)};
checkMove(_,{X,Y},{_,_},{_,Ymax},_)when Y>Ymax->%down
	[{Check,Tmp}]=ets:lookup(borders,down),{down,checkBar(Tmp,X)};
checkMove({OldX,OldY},{X,Y},_,_,Dir)->
	case checkRaduis(OldX,OldY,Dir) of
		[]->	case {read(param,light)} of
			{on} -> {on,light};
			_-> {ok,freespace}
			end;
		[H|_T]->io:format("old: ~p new: ~p person:~p~n",[{OldX,OldY},{X,Y},H]),{H,person}
	end.

checkDancefloor(X,Y,Pc)->
	case Pc of
		pc1 when X>350,Y>100-> ok;
		pc2 when X<650,Y>100-> ok;
		pc3 when X>350,Y<400-> ok;
		pc4 when X<650,Y<400-> ok;
		_-> out
	end.  

 checkRaduis(X,Y,Dir)->
	QH=case Dir of
	Z when Z==1;Z==2;Z==8->
		qlc:q([{K,V}||{{Xnew,Ynew}=K,V}<-ets:table(location),Xnew<X+?W,Xnew>X,Ynew<Y+?H,Ynew>Y-?H,Xnew/=X,Ynew/=Y]);
	Z when Z==4;Z==5;Z==6-> 
		qlc:q([{K,V}||{{Xnew,Ynew}=K,V}<-ets:table(location),Xnew<X,Xnew>X-?W,Ynew<Y+?H,Ynew>Y-?H,Xnew/=X,Ynew/=Y]);
	3->
		qlc:q([{K,V}||{{Xnew,Ynew}=K,V}<-ets:table(location),Xnew<X+?W,Xnew>X-?W,Ynew<Y,Ynew>Y-?H,Xnew/=X,Ynew/=Y]);
	7->
		qlc:q([{K,V}||{{Xnew,Ynew}=K,V}<-ets:table(location),Xnew<X+?W,Xnew>X-?W,Ynew<Y+?H,Ynew>Y,Xnew/=X,Ynew/=Y])
	end,
	qlc:eval(QH).

%cross call, when process want to move to other pc. the pc check if he can, if so, he create him
%in his pc location.
handle_call({cross,{Xold,Yold},Dir,Gender,Rank,Vec},_,ready)->
	case Dir of 
		up->X=Xold,Y=Yold-1;
		down->X=Xold,Y=Yold+1;
		right->X=Xold+1,Y=Yold;
		left->X=Xold-1,Y=Yold
	end,
	case ets:lookup(location,{X,Y}) of
		[]->Id = newProc({X,Y},Gender,Rank,Vec),
		ets:insert(location,{{X,Y},{Id,Gender}}),
		ets:insert(ranks,{{X+8,Y-15},toAtom(Rank)}),
		io:format("process moved to:{~p,~p}~n",[X,Y]),
		{reply,ok,ready};
		_->{reply,dont,ready} 
		
	end;

handle_call({keepalive},_,ready)->
	{reply,ok,ready}.

%----kill-state----
terminate(_,_)->
	io:format("pc down~n"),	
	ok.   						% terminate the pc

handle_cast({kill},_)->
	Location=ets:tab2list(location),		        	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{suicide,read(param,index),Location}),  	%send the ets with locations to main
	ets:delete(location),	
	ets:delete(ranks),
	ets:delete(param),				%delete the ets
	{stop,normal,done};						%message reply
						
%-----------------


handle_cast({readyack},set)->
	io:format("connected to main~n"),
	spawn_link(fun()->status() end),
	{noreply,ready};

%from user
handle_cast({new,Gender,{X,Y}},ready)->
	%insert to ets + check close to other process (smell or contact)
	Id = newProc({X,Y},Gender,-1,rand:uniform(8)),
	ets:insert(location,{{X,Y},{Id,Gender}}),
	io:format("new proc: ~p in {~p,~p}~n",[Gender,X,Y]),
	{noreply,ready};

handle_cast({drinking,Id,Gender,Curr},ready)->
	spawn_link(fun()->drink(Id,Gender,Curr) end),
	{noreply,ready};

handle_cast({dancing,Id,Gender,Curr},ready)->
	io:format("pc received dancing from ~p~n",[Id]),
	spawn_link(fun()->dance(Id,Gender,Curr) end),
	{noreply,ready};

handle_cast({light},ready)->
	io:format("pc received light~n"),
	ets:insert(param,{light,on}),
	spawn_link(fun()-> wait(100), ets:insert(param,{light,off}) end),
	{noreply,ready};

handle_cast({love,Id1,Id2,{X1,Y1}=Curr1,{X2,Y2}=Curr2},ready)->
	ets:delete(location,Curr1),
	ets:delete(ranks,{X1+8,Y1-15}),
	ets:delete(ranks,{X2+8,Y2-15}),
	ets:delete(location,Curr2),
	gen_statem:stop(Id1),
	gen_statem:stop(Id2),
	heart(Curr1),
	{noreply,ready};

handle_cast({dead,Id,{X,Y}=Curr},ready)->
	ets:delete(location,Curr),
	ets:delete(ranks,{X+8,Y-15}),
	gen_statem:stop(Id),
	{noreply,ready};

%walk request
handle_cast({walkreq,Old={XOld,YOld},New={XNew,YNew},Id,Cv,Gender,Dir},ready)->
	
	case ets:lookup(interaction,Id) of	%check if in cv ready or bo
		[{_,{OthrId,OtherGnder}}]-> ets:delete(interaction,Id),Reply={inter_begin,OthrId,OtherGnder};
		[]->
		[{bounds,{{Xmin,Xmax},{Ymin,Ymax}}}]=ets:lookup(param,bounds),%checking the bounds of this pc
		{EventWith,InteractionObj}=checkMove(Old,New,{Xmin,Xmax},{Ymin,Ymax},Dir),%checking what happen next move

		io:format("~p:~p~n",[EventWith,InteractionObj]),
		Reply=case InteractionObj of %reply the process the ack with the details for is requset
			bar-> io:format("sent bar to the process~n"),
				case Cv of
					ready->{bar};
					bo-> {wall,EventWith}
				end;
			light-> %update ets
				[{Old,Data}]=ets:lookup(location,Old),
				ets:delete(location,Old),
				ets:delete(ranks,{XOld+8,YOld-15}),
				ets:insert(location,{New,Data}),
				ets:insert(ranks,{{XNew+8,YNew-15},toAtom(read(param,{Id,rank}))}),
				{dance};
			wall->io:format("sent wall to the process~n"),
				{wall,EventWith};
			person->io:format("sent person to the process~n"),
				{{OtherX,OtherY},{OtherId,OtherGender}}=EventWith,		
				OtherCv = read(param,{OtherId,cv}),
				case {Cv,OtherCv} of
					{Cv,OtherCv} when Cv==bo;OtherCv/=ready->	{wall,person};
			
					_-> 		ets:insert(interaction,{OtherId,{Id,Gender}}),
							{inter_wait,OtherId,OtherGender} 
				end;
			freespace->io:format("sent freespace to the process~n"),
				%update ets
				[{Old,Data}]=ets:lookup(location,Old),
				ets:delete(location,Old),
				ets:delete(ranks,{XOld+8,YOld-15}),
				ets:insert(location,{New,Data}),
				ets:insert(ranks,{{XNew+8,YNew-15},toAtom(read(param,{Id,rank}))}),
				noreply;
			_->io:format("sent cross to the process~n"),
				try sendCrossRequst(InteractionObj,Old,EventWith,Gender,read(param,{Id,rank}),Dir,Id) of
					ReturnValue->ReturnValue
				catch
					 exit:Exit->{wall,EventWith}
				end
					
		end
	end,
	case Reply of
		noreply-> ok;
		Msg->	gen_statem:cast(Id,Msg)
	end,
	{noreply,ready}.



sendCrossRequst(PC,Old={XOld,YOld},EventWith,Gender,Rank,Vec,Id)->
		case gen_server:call({gs,PC},{cross,Old,EventWith,Gender,Rank,Vec}) of
			ok->ets:delete(location,Old),ets:delete(ranks,{XOld+8,YOld-15}),gen_statem:stop(Id),noreply;%if cross, kill the process
			_->{wall,EventWith}
		end.	


% for each pc, set what he see in the board, in the init stage
makeBorders(PC)->
	case PC of
	pc1->ets:insert(borders,[{up,wallbar},{down,?PC3},{right,?PC2},{left,wall}]);
	pc2->ets:insert(borders,[{up,wallbar},{down,?PC4},{right,wall},{left,?PC1}]);
	pc3->ets:insert(borders,[{up,?PC1},{down,wallbar},{right,?PC4},{left,wall}]);
	pc4->ets:insert(borders,[{up,?PC2},{down,wallbar},{right,wall},{left,?PC3}])
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



heart({X,Y})->
	spawn(pc,heart,[X,Y,[h1,h1,h1,h2,h3,h4,h5,h6|[]]]).
heart(X,Y,[])-> ets:delete(ranks,{X,Y});
heart(X,Y,[H|T])->
	ets:insert(ranks,{{X,Y},H}),
	wait(150),
	heart(X,Y,T).

wait(X)->
	receive
		after X-> ok
	end.

newProc({X,Y},Gender,Rank,Dir)->
	Cnt = read(param,proc_id),
	Pc = case read(param,index) of
		pc1->?PC1;
		pc2->?PC2;
		pc3->?PC3;
		pc4->?PC4
	end,
	spawn(proc,start_link,[Cnt,{{X,Y},Gender,Rank,Dir},Pc]),
	write(param,proc_id,Cnt+1),
	toAtom(Cnt).

drink(Id,Gender,Curr)->
	drink(Id,Gender,Curr,6).

drink(Id,Gender,Curr,0)->
	ets:insert(location,{Curr,{Id,Gender}});
drink(Id,Gender,Curr,N)->
	Pic = case {Gender,N rem 2} of
		{male,0}-> drink1male; {male,1}-> drink2male; 
		{female,0}->drink1female; {female,1}-> drink2female end,
	ets:insert(location,{Curr,{Id,Pic}}),
	wait(500),
	drink(Id,Gender,Curr,N-1).

dance(Id,Gender,Curr)->
	case Gender of
		male-> dance(Id,Gender,Curr,5000,[d1male,d2male,d3male,d4male|[]]);
		female->  dance(Id,Gender,Curr,5000,[d1female,d2female,d3female,d4female|[]])
	end.
dance(Id,Gender,Curr,0,_)->
	ets:insert(location,{Curr,{Id,Gender}});
dance(Id,Gender,Curr,Time,[H|T])->
	ets:insert(location,{Curr,{Id,H}}),
	wait(250),
	dance(Id,Gender,Curr,Time-250,T++[H]).

toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).
