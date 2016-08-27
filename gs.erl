-module(gs).
-behaviour(gen_server).
-compile(export_all).
-define(PCS,4).
-define(N,424).
-define(M,944).

%   _____               _____                          
%  / ____|             / ____|                         
% | |  __  ___ _ __   | (___   ___ _ ____   _____ _ __ 
% | | |_ |/ _ \ '_ \   \___ \ / _ \ '__\ \ / / _ \ '__|
% | |__| |  __/ | | |  ____) |  __/ |   \ V /  __/ |   
%  \_____|\___|_| |_| |_____/ \___|_|    \_/ \___|_|   
%                                                     
%         By: Itay Sagiv & Asaf Azzura
%-------------------------------------
start_link()->								%func to start the gen server
	gen_server:start_link({local,gs},gs,[],[]).

init(_)->
	spawn_link(demo,start,[]),					%set up the graphics
	ets:new(pc,[set,named_table,public]),				%set ets to save pcs
	ets:new(param,[set,named_table,public]),			%set ets to save the paramters
	ets:insert(param,{light,lightoff}),				%insert light status
	ets:new(location,[set,named_table,public]),			%set ets to save locations
	ets:insert(location,[{pc1,[]},{pc2,[]},{pc3,[]},{pc4,[]}]),	%insert the pcs location (start with empty value)
	ets:new(ranks,[set,named_table,public]),			%start ets to save ranks
	ets:insert(ranks,[{pc1,[]},{pc2,[]},{pc3,[]},{pc4,[]}]),  	%insert the pcs ranks (start with empty value)
	ets:insert(param,{connect_cnt,0}),				%insert status of how much pc connected
	ets:new(walk_pics,[set,named_table,public]),
	ets:insert(walk_pics,[{pc1,[]},{pc2,[]},{pc3,[]},{pc4,[]}]),
	spawn_link(fun()->wait(50000),gen_server:cast(gs,{timeout}) end), %set timer to 50 sec - if not all 4 pcs connect - shut down
	
	{ok,set}.
%------------------------------------

%keep alive func it to check if all the 4 pc are still connceted to the gen server, if not, the server 
% know how to treat it and make sure that atleast the other pcs will work
keepAlive()->
	keepAlive([{Key,X}|| {Key,{_,X}}<-ets:tab2list(pc)]),%lc to get & save the pc full name
	keepAlive().

keepAlive([])->ok;					%empty, go check other round now
keepAlive([{Key,Pc}|T])->				%run over list of all pc and check if alive
	wait(1000),
 	try gen_server:call({gs,Pc},{keepalive}) of
		_OK->ok					%alive
	catch						%got error, pc down. switch is screen with a sign
		exit:_Exit->io:format("exit: ~p is down ~n",[Key]),
		DarkLoc = case Key of
			pc1-> {175,35}; pc2-> {675,35}; pc3-> {175,285}; pc4-> {675,285}
			end,
		
		Inherit = case Key of
			pc1-> Old=pc3,pc2;
			pc2-> Old=pc4,pc1;
			pc3-> Old=pc1,pc4;
			pc4-> Old=pc2,pc3
		end,
		SaveLocation = read(location,Key),
		SaveRanks = read(ranks,Key),
		SaveWalks = read(walk_pics,Key),
		try gen_server:call(read(pc,Inherit),{restore,SaveLocation,SaveRanks,SaveWalks,Key,read(pc,Old)}) of
			_Ok-> ets:insert(location,{Key,[]})
		catch
			exit:_Exit->
			ets:insert(location,{Key,[{DarkLoc,{'-1',dark}}]})
		end,
		ets:insert(ranks,{Key,[]}),
		ets:insert(walk_pics,{Key,[]}),
		ets:delete(pc,Key)
	end,keepAlive(T).
	

%sends acks to all pc that connected so they start send status
sendacks(0)->	io:format("all acks sent~n"),spawn(fun()->wait(1000),keepAlive() end),
spawn_link(fun()->loop() end); % all pc connected, create loop to get updates from pc
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

handle_cast({next_pic,Old,New,NewDir},ready)->
	{Num,Gender,_OldDir}=read(walk_pics,Old),
	ets:delete(walk_pics,Old),
	NewNum=((Num+1)rem 4),
	ets:insert(walk_pics,{New,{NewNum,Gender,NewDir}}),
	{noreply,ready};

handle_cast({new_walk,Loc,Gender,Dir},ready)->
	ets:insert(walk_pics,{Loc,{0,Gender,Dir}}),
	{noreply,ready};

handle_cast({kill_walk,Loc},ready)->
	ets:delete(walk_pics,Loc),
	{noreply,ready};

%handles the time out in the setting
handle_cast({timeout},set)->
	gen_server:cast(gs,{kill}),
	{noreply,error};
handle_cast({timeout},State)->
	{noreply,State};
handle_cast({kill},_)->
	{stop,normal,done};
handle_cast({status,Index,Locations,Ranks,Walks},ready)->
	ets:insert(location,{Index,Locations}),
	ets:insert(ranks,{Index,Ranks}),
	ets:insert(walk_pics,{Index,Walks}),
	{noreply,ready};

handle_cast({menu_create,Gender,{X,Y}},ready)->
	create(Gender,X,Y),
	{noreply,ready};
handle_cast({menu_random},ready)->
	create(5),
	{noreply,ready};
handle_cast({menu_light},ready)->
	spawn_link(fun()->light() end),
	{noreply,ready}.
%temrinate for gen server
terminate(_,_)->
	io:format("server down~n"),
	ok.	

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

%loop for update the canvas every 0.1 sec
loop()->
	receive
		after 100-> ok
	end,
	canvas!{wx,-220,{wx_ref,74,wxButton,[]},[],{wxCommand,command_button_clicked,[],0,0}},
	loop().

%--function for light in the dance floor--
light()->
	[gen_server:cast({gs,Pc},{light})||{_,{_,Pc}}<-ets:tab2list(pc)],%send pc that light start
	light([light1,light2,light3|[]],0,10). % run the light pics
light(_,N,N)->
	ets:insert(param,{light,lightoff});
light([H|T],N,Stop)->
	ets:insert(param,{light,H}),
	wait(500),
%------------------------------------------
	light(T++[H],N+1,Stop).

wait(X)->%function that make wait for X time
	receive
		after X-> ok
	end.
%  _    _                 _____       _____       _   
% | |  | |               |_   _|     |  __ \     | |  
% | |  | |___  ___ _ __    | |  _ __ | |__) |   _| |_ 
% | |  | / __|/ _ \ '__|   | | | '_ \|  ___/ | | | __|
% | |__| \__ \  __/ |     _| |_| | | | |   | |_| | |_ 
%  \____/|___/\___|_|    |_____|_| |_|_|    \__,_|\__|                                                    
%------------------------------------------------------
%     The next funcation are for the user
%	With them he can create processes

%get number of process the user want, and create them randomly
create(0)->ok;
create(N)-> X=rand:uniform(?M),Y=rand:uniform(?N),case rand:uniform(2) of
1->G=male;
_->G=female end, create(G,X,Y),
create(N-1).

create(Gender,X,Y) when X<?M/2 , Y<?N/2->	[{pc1,From}]=ets:lookup(pc,pc1), gen_server:cast(From,{new,Gender,{X,Y}});%create in pc1	
create(Gender,X,Y) when X>=?M/2 , Y<?N/2->	[{pc2,From}]=ets:lookup(pc,pc2), gen_server:cast(From,{new,Gender,{X,Y}});%create in pc2
create(Gender,X,Y) when X<?M/2 , Y>=?N/2->	[{pc3,From}]=ets:lookup(pc,pc3), gen_server:cast(From,{new,Gender,{X,Y}});%create in pc3
create(Gender,X,Y) when X>=?M/2 , Y>=?N/2->	[{pc4,From}]=ets:lookup(pc,pc4), gen_server:cast(From,{new,Gender,{X,Y}}).%create in pc4


