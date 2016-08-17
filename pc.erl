-module(pc).
-behaviour(gen_server).
-compile(export_all).
-define(MAIN,'main@itay-VirtualBox').

%open gs
start_link(Num)->
	gen_server:start_link({local,Num},pc,[Num],[]).	%start gs

%init function, start the ets
init([Num]) ->
	io:format("init: ~p~n",[Num]),
	ets:new(db_location,[bag,named_table]),		    %for holding the process that will run in my corner
	ets:new(param,[set,named_table]),		    %for paramters
	ets:insert(param,{index,Num}),			    %add my number to ets, this number will say which corner in the map i manege
	gen_server:call({gs,?MAIN},{ready,Num}),%send main im ready
	spawn(fun()->status() end),
	{ok,ready}.				            %done


status()->%function that send the main the status if the pc with the location of all the proesses in this pc
	receive %wait
	after 1000->ok
	end, %end wait
	Location=ets:tab2list(db_location),		       	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{status,Location}),  	%send the ets with locations to main
	status(). 

%----kill-state----
terminate(normal,kill)->ok.   						% terminate the pc
handle_call({kill},_,ready)->
	Location=ets:tab2list(db_location),		        	%save all locations ets in list
	gen_server:cast({gs,?MAIN},{suicide,Location}),  	%send the ets with locations to main
	ets:delete(location),ets:delete(param),				%delete the ets
	{stop,normal,suicide}.						%message reply
						
%-----------------

%from user
handle_cast({new,Gender,{X,Y}},ready)->
	%ets:insert(location),
	{noreply,ready};


%from other pc
handle_cast({cross,Gender,{X,Y},{TimeMovement,DirMovement}},ready)->
	%ets:insert(location),
	%----
	% here code for chcking the rest movment and sending to the procsess how much he can move
	%----
	{noreply,ready}.



proccessFromUser()->ok.


proccessFromOtherPC()->ok.

proccess()->ok.


lightON()->ok.





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


