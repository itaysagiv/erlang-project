-module(pc).
-behaviour(gen_server).
-export([start_link/1,init/1,handle_call/3,handle_cast/2,code_change/3,handle_info/2,terminate/2,kill/0,pow/3,heart/3]).
-include_lib("stdlib/include/qlc.hrl").
-define(MAIN,'main@asaf-VirtualBox').
-define(N,424).
-define(M,944).
-define(W,28).
-define(H,39).
-define(SMELL_R,150).
-define(PC1,'pc1@asaf-VirtualBox').
-define(PC2,'pc2@asaf-VirtualBox').
-define(PC3,'pc3@asaf-VirtualBox').
-define(PC4,'pc4@asaf-VirtualBox').

%  ________                ___________________  
% /  _____/  ____   ____   \______   \_   ___ \ 
%/   \  ____/ __ \ /    \   |     ___/    \  \/ 
%\    \_\  \  ___/|   |  \  |    |   \     \____
% \______  /\___  >___|  /  |____|    \______  /
%        \/     \/     \/                    \/ 
%
%	By: Itay Sagiv & Asaf Azzura
%---------------------------------------------------------
%    starting the gen server and init it
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
	ets:insert(param,{light,off}),			    %insert defualt light status
	ets:new(interaction,[set,named_table]),		    %start ets for interactions
	ets:new(ranks,[set,named_table,public]),	    %start ets for ranks
	ets:new(walk_pics,[set,named_table,public]),
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
	Walk = ets:tab2list(walk_pics),
	gen_server:cast({gs,?MAIN},{status,read(param,index),Location,Ranks,Walk}),  	%send the ets with locations to main
	status(). 
%---------------------------------------------------------

%checking if process who bumped wallbar, if its the bar part or the wall part
checkBar(Tmp,X)->
	case Tmp of
	wallbar-> case X of 
		X when X>?M-396;X<396->bar;
		_->wall
	end;
	_->Tmp
end.

%function that check what will be in the next more of process
checkMove(_,{X,_},{Xmin,_},{_,_},_,_,_)when X<Xmin->%left
	[{_Check,Tmp}]=ets:lookup(borders,left),{left,checkBar(Tmp,X)};
checkMove(_,{X,_},{_,Xmax},{_,_},_,_,_)when X>Xmax->%right
	[{_Check,Tmp}]=ets:lookup(borders,right),{right,checkBar(Tmp,X)};
checkMove(_,{X,Y},{_,_},{Ymin,_},_,_,_)when Y<Ymin->%up
	[{_Check,Tmp}]=ets:lookup(borders,up),
	case Tmp of 		%this case if for when pc down, its will switch the call to the other pc
		{L,_R} when X=<?M/2 -> {up,checkBar(L,X)};
		{_L,R} -> {up,checkBar(R,X)};
		_-> 	{up,checkBar(Tmp,X)}
	end;
checkMove(_,{X,Y},{_,_},{_,Ymax},_,_,_)when Y>Ymax->%down
	[{_Check,Tmp}]=ets:lookup(borders,down),
	case Tmp of		%this case if for when pc down, its will switch the call to the other pc
		{L,_R} when X=<?M/2 -> {down,checkBar(L,X)};
		{_L,R} -> {down,checkBar(R,X)};
		_-> 	{down,checkBar(Tmp,X)}
	end;
checkMove({OldX,OldY},{X,Y},_,_,Dir,Gender,Id)->%not eage move, check if free space or person or need to dance
	case checkRaduis(OldX,OldY,Dir)  of
		[]-> case Gender of
			male-> case checkSmell(OldX,OldY)of {ok,SmellDir}->gen_statem:cast(Id,{smell,SmellDir});_->ok end;
			_->ok
			end,
			case {read(param,light)} of
				{on} -> {on,light};
				_-> {ok,freespace}
				end;
		[H|_T]->io:format("old: ~p new: ~p person:~p~n",[{OldX,OldY},{X,Y},H]),{H,person}
		end.

%checkDancefloor(X,Y,Pc)->
%	case Pc of
%		pc1 when X>350,Y>100-> ok;
%		pc2 when X<650,Y>100-> ok;
%		pc3 when X>350,Y<400-> ok;
%		pc4 when X<650,Y<400-> ok;
%		_-> out
%	end.  

%func for checking if other person is in my raduis by using qlc for raduis
%calc it by the way the person is looking
 checkRaduis(X,Y,Dir)->
	QH=case Dir of		%case for each direction and what he sees
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

%func for smelling, checking raduis for female and change the dir for it
checkSmell(X,Y)->
	QH=qlc:q([K||{{Xnew,Ynew}=K,{_,Gender}}<-ets:table(location),Gender==female,Xnew<X+?SMELL_R,Xnew>X-?SMELL_R,Ynew<Y+?SMELL_R,Ynew>Y-?SMELL_R]),
	case qlc:eval(QH) of
		[{XSmell,YSmell}|_T]-> case {{X,Y},{XSmell,YSmell}} of %change the male diraction acording the female diraction
						_ when Y==YSmell , X<XSmell -> {ok,1};
						_ when Y>YSmell , X<XSmell -> {ok,2};
						_ when Y>YSmell , X==XSmell -> {ok,3};
						_ when Y>YSmell , X>XSmell -> {ok,4};
						_ when Y==YSmell , X>XSmell -> {ok,5};
						_ when Y<YSmell , X>XSmell -> {ok,6};
						_ when Y<YSmell , X==XSmell -> {ok,7};
						_ when Y<YSmell , X<XSmell -> {ok,8}		
					end;
		_-> {nosmell}
	end.

%  _    _                 _ _         _____      _ _ 
% | |  | |               | | |       / ____|    | | |
% | |__| | __ _ _ __   __| | | ___  | |     __ _| | |
% |  __  |/ _` | '_ \ / _` | |/ _ \ | |    / _` | | |
% | |  | | (_| | | | | (_| | |  __/ | |___| (_| | | |
% |_|  |_|\__,_|_| |_|\__,_|_|\___|  \_____\__,_|_|_|
%=====================================================

%this handle is when other pc down, is partner pc switch to his place
handle_call({restore,_Location,_Ranks,_Walks,Pc,Old},_,ready)->
	case Pc of %checking if pc1/2 or pc3/4 and set the new borders
		X when X==pc1;X==pc2-> 	ets:insert(borders,[{up,wallbar},{down,{?PC3,?PC4}},{right,wall},{left,wall}]),
				       	ets:insert(param,{bounds,{{1,?M},{1,?N/2}}}),
				       	gen_server:cast(Old,{update_border,{up,read(param,index)}});
		_->		       	ets:insert(borders,[{up,{?PC1,?PC2}},{down,wallbar},{right,wall},{left,wall}]),
				       	ets:insert(param,{bounds,{{1,?M},{(?N/2)+1,?N}}}),
					gen_server:cast(Old,{update_border,{down,read(param,index)}})
	end,
	{reply,ok,ready};

%cross call, when process want to move to other pc. the pc check if he can, if so, he create him
%in his pc location.
handle_call({cross,{Xold,Yold},Dir,Gender,Rank,Vec},_,ready)->
	case Dir of %create the new process in the old place +1 to the right direction
		up->X=Xold,Y=Yold-1;
		down->X=Xold,Y=Yold+1;
		right->X=Xold+1,Y=Yold;
		left->X=Xold-1,Y=Yold
	end,
	case ets:lookup(location,{X,Y}) of		%checking if the new place doesnt have person on it already, if not create, if yes,wall
		[]->Id = newProc({X,Y},Gender,Rank,Vec),
		ets:insert(location,{{X,Y},{Id,Gender}}), 	%set gender
		ets:insert(ranks,{{X+8,Y-15},toAtom(Rank)}),	%set rank pic
		io:format("process moved to:{~p,~p}~n",[X,Y]),
		{reply,ok,ready};
		_->{reply,dont,ready} 
		
	end;

%just for answering keep alive for showing this pc still running
handle_call({keepalive},_,ready)->
	{reply,ok,ready}.

%----kill-state----
terminate(_,_)->
	io:format("pc down~n"),	
	ok.   						% terminate the pc



%  _    _                 _ _         _____          _   
% | |  | |               | | |       / ____|        | |  
% | |__| | __ _ _ __   __| | | ___  | |     __ _ ___| |_ 
% |  __  |/ _` | '_ \ / _` | |/ _ \ | |    / _` / __| __|
% | |  | | (_| | | | | (_| | |  __/ | |___| (_| \__ \ |_ 
% |_|  |_|\__,_|_| |_|\__,_|_|\___|  \_____\__,_|___/\__|
%=========================================================                                                       

%cast the sending new borders for the backup pc
handle_cast({update_border,{Key,Val}},ready)->
	Pc = case Val of
		pc1->?PC1;pc2->?PC2;pc3->?PC3;pc4->?PC4
	end,
	ets:insert(borders,{Key,Pc}),
	{noreply,ready};

%cast for killing pc, delete all of is ets and processing
handle_cast({kill},_)->
	Location=ets:tab2list(location),		        	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{suicide,read(param,index),Location}),%send the ets with locations to main
	ets:delete(location),	
	ets:delete(ranks),
	ets:delete(param),						%delete the ets
	{stop,normal,done};						%message reply
						
%-----------------

%cast for sending ready to gs and start status pc
handle_cast({readyack},set)->
	io:format("connected to main~n"),
	spawn_link(fun()->status() end),
	{noreply,ready};

%from user
handle_cast({new,Gender,{X,Y}},ready)->
	%insert to ets + check close to other process (smell or contact)
	case ets:lookup(location,{X,Y}) of
	[]->
	Id = newProc({X,Y},Gender,-1,rand:uniform(8)),
	ets:insert(location,{{X,Y},{Id,Gender}}),
	io:format("new proc: ~p in {~p,~p}~n",[Gender,X,Y]);
	_->ok end,
	{noreply,ready};
%cast for drinking
handle_cast({drinking,Id,Gender,Curr},ready)->
	spawn_link(fun()->drink(Id,Gender,Curr) end),%call drinking function for timer
	{noreply,ready};
%cast for dancing
handle_cast({dancing,Id,Gender,Curr},ready)->
	io:format("pc received dancing from ~p~n",[Id]),
	spawn_link(fun()->dance(Id,Gender,Curr) end),%call dance function for timer
	{noreply,ready};
%cast for light
handle_cast({light},ready)->
	io:format("pc received light~n"),
	ets:insert(param,{light,on}),
	spawn_link(fun()-> wait(100), ets:insert(param,{light,off}) end),
	{noreply,ready};
%cast for love animation, delete those 2 persons and the ranks
handle_cast({love,Id1,Id2,{X1,Y1}=Curr1,{X2,Y2}=Curr2},ready)->
	ets:delete(location,Curr1),
	ets:delete(ranks,{X1+8,Y1-15}),
	ets:delete(ranks,{X2+8,Y2-15}),
	ets:delete(location,Curr2),
	gen_statem:stop(Id1),
	gen_statem:stop(Id2),
	heart({X1-30,Y1-30}),%call heart function animation
	{noreply,ready};
%cast for pow animation
handle_cast({pow,{X,Y}},ready)->
	pow({X-40,Y-40}),
	{noreply,ready};
%cast for dead, deleting the procsess
handle_cast({dead,Id,{X,Y}=Curr},ready)->
	ets:delete(location,Curr),
	ets:delete(walk_pics,Curr),
	ets:delete(ranks,{X+8,Y-15}),
	gen_statem:stop(Id),
	
	{noreply,ready};

%walk request
%the process sending the pc that he want to walk and where, as long its ok the pc will not sending him message,
%but if the process got interaction. the pc will send him dont move and do the interaction.
handle_cast({walkreq,Old={XOld,YOld},New={XNew,YNew},Id,Cv,Gender,Dir},ready)->
	
	case ets:lookup(interaction,Id) of	%check if in cv ready or bo
		[{_,{OthrId,OtherGnder}}]-> ets:delete(interaction,Id),Reply={inter_begin,OthrId,OtherGnder};
		[]->
		[{bounds,{{Xmin,Xmax},{Ymin,Ymax}}}]=ets:lookup(param,bounds),%checking the bounds of this pc
		{EventWith,InteractionObj}=checkMove(Old,New,{Xmin,Xmax},{Ymin,Ymax},Dir,Gender,Id),%checking what happen next move

		io:format("~p:~p~n",[EventWith,InteractionObj]),
		Reply=case InteractionObj of %reply the process the ack with the details for is requset
			bar-> io:format("sent bar to the process~n"),
				case Cv of
					ready->{bar};
					bo-> {wall,EventWith}
				end;
			light-> %update ets
				case ets:lookup(location,Old) of
				[]-> gen_statem:stop(Id);
				[{Old,Data}]-> 
				ets:delete(location,Old),
				ets:delete(ranks,{XOld+8,YOld-15}),
				ets:insert(location,{New,Data}),
				ets:insert(ranks,{{XNew+8,YNew-15},toAtom(read(param,{Id,rank}))}),
				{Num,_G,_OldDir}=read(walk_pics,Old),
				ets:delete(walk_pics,Old),
				NewNum=((Num+1)rem 4),
				ets:insert(walk_pics,{New,{NewNum,Gender,Dir}})
				end,				
				{dance};
			wall->io:format("sent wall to the process~n"),
				{wall,EventWith};%sening wall
			person->io:format("sent person to the process~n"),
				{{_OtherX,_OtherY},{OtherId,OtherGender}}=EventWith,		
				OtherCv = read(param,{OtherId,cv}),
				case {Cv,OtherCv} of
					{Cv,OtherCv} when Cv==bo;OtherCv/=ready->	{wall,person};
			
					_-> 		ets:insert(interaction,{OtherId,{Id,Gender}}),
							{inter_wait,OtherId,OtherGender} 
				end;
			freespace->io:format("sent freespace to the process~n"),
				%update ets
				case ets:lookup(location,Old) of
				[]-> gen_statem:stop(Id);%we deleting the old place and updating the new place with the next walking picture
				[{Old,Data}]-> 
				ets:delete(location,Old),
				ets:delete(ranks,{XOld+8,YOld-15}),
				ets:insert(location,{New,Data}),
				ets:insert(ranks,{{XNew+8,YNew-15},toAtom(read(param,{Id,rank}))}),
				{Num,_G,_OldDir}=read(walk_pics,Old),
				ets:delete(walk_pics,Old),
				NewNum=((Num+1)rem 4),
				ets:insert(walk_pics,{New,{NewNum,Gender,Dir}})
				end,
				noreply;
			_->io:format("sent cross to the process~n"),
				try sendCrossRequst(InteractionObj,Old,EventWith,Gender,read(param,{Id,rank}),Dir,Id) of
					ReturnValue->ReturnValue
				catch
					 exit:_Exit->{wall,EventWith}
				end
					
		end
	end,
	case Reply of
		noreply-> ok;
		Msg->	gen_statem:cast(Id,Msg)
	end,
	{noreply,ready}.


%function for handling the cross call
sendCrossRequst(PC,Old={XOld,YOld},EventWith,Gender,Rank,Vec,Id)->
		case gen_server:call({gs,PC},{cross,Old,EventWith,Gender,Rank,Vec}) of
			ok->	ets:delete(location,Old), %got ok, delete the process from me
				ets:delete(ranks,{XOld+8,YOld-15}),
				gen_statem:stop(Id),
				ets:delete(walk_pics,Old),		
				noreply;%if cross, kill the process
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

%--function to help handle ets easly--
%-read: reading from the ets easliy with tab and key
%-write: writing from the ets easliy with tab and key
read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).

kill()->gen_server:stop(gs).


%heart animation 
heart({X,Y})->
	spawn(pc,heart,[X,Y,[h1,h1,h1,h2,h3,h4,h5,h6|[]]]).
heart(X,Y,[])-> ets:delete(ranks,{X,Y});
heart(X,Y,[H|T])->
	ets:insert(ranks,{{X,Y},H}),
	wait(150),
	heart(X,Y,T).
%ka-pow animation
pow({X,Y})->
	spawn(pc,pow,[X,Y,[pow1,pow2,pow3,pow4,pow5,pow5,pow5|[]]]).
pow(X,Y,[])-> ets:delete(ranks,{X,Y});
pow(X,Y,[H|T])->
	ets:insert(ranks,{{X,Y},H}),
	wait(100),
	pow(X,Y,T).

wait(X)->
	receive
		after X-> ok
	end.

%func for creating new process
newProc({X,Y},Gender,Rank,Dir)->
	Cnt = read(param,proc_id),
	Pc = case read(param,index) of%checking which pc.
		pc1->?PC1;
		pc2->?PC2;
		pc3->?PC3;
		pc4->?PC4
	end,
	spawn(proc,start_link,[Cnt,{{X,Y},Gender,Rank,Dir},Pc]),
	ets:insert(walk_pics,{{X,Y},{0,Gender,Dir}}),
	write(param,proc_id,Cnt+1),
	toAtom(Cnt).

%func for handling the drinking on the bar
drink(Id,Gender,Curr)->
	drink(Id,Gender,Curr,6).
drink(Id,Gender,Curr,0)->
	ets:insert(location,{Curr,{Id,Gender}});
drink(Id,Gender,Curr,N)->
	Pic = case {Gender,N rem 2} of%for each gender.
		{male,0}-> drink1male; {male,1}-> drink2male; 
		{female,0}->drink1female; {female,1}-> drink2female end,
	ets:insert(location,{Curr,{Id,Pic}}),
	wait(500),
	drink(Id,Gender,Curr,N-1).

%func for handling the dancing
dance(Id,Gender,Curr)->
	case Gender of		%picking the pictures for the right gender.
		male-> dance(Id,Gender,Curr,5000,[d1male,d2male,d3male,d4male|[]]);
		female->  dance(Id,Gender,Curr,5000,[d1female,d2female,d3female,d4female|[]])
	end.
dance(Id,Gender,Curr,0,_)->
	ets:insert(location,{Curr,{Id,Gender}});
dance(Id,Gender,Curr,Time,[H|T])->
	ets:insert(location,{Curr,{Id,H}}),
	wait(250),%wait time for the next picture
	dance(Id,Gender,Curr,Time-250,T++[H]).
%func to change list to atom
toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).
code_change(_,_,_)->ok.
handle_info(_,_)->ok.
