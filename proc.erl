-module(proc).
-export([start_link/3,init/1,handle_event/4,terminate/3,code_change/4]).
-behaviour(gen_statem).
-define(CB_MODE, handle_event_function).
-define(STEP_SIZE, 3).


%  _____                                         _____               _____ _        _                 
% |  __ \                                       / ____|             / ____| |      | |                
% | |__) | __ ___   ___ ___  ___ ___   ______  | |  __  ___ _ __   | (___ | |_ __ _| |_ ___ _ __ ___  
% |  ___/ '__/ _ \ / __/ _ \/ __/ __| |______| | | |_ |/ _ \ '_ \   \___ \| __/ _` | __/ _ \ '_ ` _ \ 
% | |   | | | (_) | (_|  __/\__ \__ \          | |__| |  __/ | | |  ____) | || (_| | ||  __/ | | | | |
% |_|   |_|  \___/ \___\___||___/___/           \_____|\___|_| |_| |_____/ \__\__,_|\__\___|_| |_| |_|
%
%	By: Itay Sagiv & Asaf Azzura
%                                                                                                                                                                                                      
%
%start the gen statem func
start_link(Reg,{{_X,_Y},_Gender,_Rank,_Dir}=Data,Pc)->
	gen_statem:start_link({local,toAtom(Reg)},proc,[Data,toAtom(Reg),Pc],[]).

%Set up the gen statem
init([{{X,Y},Gender,Rank,Dir},Reg,Pc])->
	io:format("started process in ~p~n",[Reg]),
	ets:insert(param,{{Reg,curr},{X,Y}}),		%insert is current location
	ets:insert(param,{{Reg,gender},Gender}),	%insert is gender
	case Rank of					%for new process create randmloy rank, for process who cross from other pc, save is rank
	-1 -> ets:insert(param,{{Reg,rank},rand:uniform(5)+2});
	_->ets:insert(param,{{Reg,rank},Rank})
	end,
	ets:insert(ranks,{{X+8,Y-15},toAtom(read(param,{Reg,rank}))}),%insert rank pic
	ets:insert(param,{{Reg,cv},ready}),		%insert is cv (defualt is 'ready')
	
	Data = #{cv=>ready,dir=>Dir,id=>Reg, pc=>Pc},	%set up is data
	spawn_link(fun()->step(Reg) end),		%start is walking progarm with 2 spawns
	spawn_link(fun()->changeDir(Reg) end),
	{?CB_MODE,walk,Data}.

% _                     _ _                             _       
%| |__   __ _ _ __   __| | | ___    _____   _____ _ __ | |_ ___ 
%| '_ \ / _` | '_ \ / _` | |/ _ \  / _ \ \ / / _ \ '_ \| __/ __|
%| | | | (_| | | | | (_| | |  __/ |  __/\ V /  __/ | | | |_\__ \
%|_| |_|\__,_|_| |_|\__,_|_|\___|  \___| \_/ \___|_| |_|\__|___/
%================================================================                                                               
%

%    ___                         
%   /   \ __ _  _ __    ___  ___ 
%  / /\ // _` || '_ \  / __|/ _ \
% / /_//| (_| || | | || (__|  __/
%/___,'  \__,_||_| |_| \___|\___|                                
%--------------------------------------------------------------

%those handles are for the dancing part, its has event that start the dancing and stop them.
handle_event(cast,{dance},walk,#{id := Id, cv := ready}=Data)->
	io:format("process ~p received dance~n",[Id]),
	gen_server:cast(gs,{dancing,Id,read(param,{Id,gender}),read(param,{Id,curr})}),
	spawn_link(fun()->timer(5000,Id,{stop_dance}) end),	%start timer to tell stop dancing
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{cv := bo}};
handle_event(cast,{dance},_,Data)->
	{keep_state,Data};
handle_event(cast,{stop_dance},stop,#{id := Id}=Data)->
	spawn_link(fun()->timer(3000,Id,{stop_bo}) end),	%start timer for stop BO and move to ready
	{next_state,walk,Data};

%______        _         _     _               
%|  _  \      (_)       | |   (_)              
%| | | | _ __  _  _ __  | | __ _  _ __    __ _ 
%| | | || '__|| || '_ \ | |/ /| || '_ \  / _` |
%| |/ / | |   | || | | ||   < | || | | || (_| |
%|___/  |_|   |_||_| |_||_|\_\|_||_| |_| \__, |
%                                         __/ |
%                                        |___/ 
%-----------------------------------------------
%handles for the drinking state
handle_event(cast,{bar},walk,#{id := Id, dir := Dir}=Data)->
	Impact = case Dir of
		X when X>=1,X<5 -> up;
		_-> down
		end,
	_NewDir = stepBack(Id,Dir,Impact),
	gen_server:cast(gs,{drinking,Id,read(param,{Id,gender}),read(param,{Id,curr})}),
	spawn_link(fun()->timer(3000,Id,{stop_drink}) end), %timer to stop drinking
	MyRank=read(param,{Id,rank}),
	case read(param,{Id,gender}) of		%male get+1 for drinking, female -1
		male-> ets:insert(param,{{Id,rank},MyRank+1});
		female when MyRank/=1-> ets:insert(param,{{Id,rank},MyRank-1});
		_-> ok
	end,
	spawn_link(fun()-> checkRank(Id) end), %for updating rank
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{cv := bo}};

handle_event(cast,{stop_drink},stop,#{id := Id}=Data)->
	spawn_link(fun()->timer(3000,Id,{stop_bo}) end),%timer to stop bo and return to ready
	{next_state,walk,Data};

%  _____         _                           _    _               
% |_   _|       | |                         | |  (_)              
%   | |   _ __  | |_  ___  _ __  __ _   ___ | |_  _   ___   _ __  
%   | |  | '_ \ | __|/ _ \| '__|/ _` | / __|| __|| | / _ \ | '_ \ 
%  _| |_ | | | || |_|  __/| |  | (_| || (__ | |_ | || (_) || | | |
% |_____||_| |_| \__|\___||_|   \__,_| \___| \__||_| \___/ |_| |_|
%-------------------------------------------------------------------                                                                 

%handles for the interaction,getting my id and the other id                                                             
handle_event(cast,{inter_wait,_OtherId,_OtherGender},walk,#{dir := Dir , id := Id}=Data)->%for waiting and timing
	NewDir=stepBack(Id,Dir,person),			%dont take the next step
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{ dir :=  NewDir, cv := bo}};
handle_event(cast,{end_inter},stop,#{id := Id}=Data)->	%for ending interaction
	spawn_link(fun()->checkRank(Id) end),		%update rank, its on new process because we dont want to stop the process in is 
							%moving, and we create a new process who checking if the new rank is 0 and send 
							%the pc to kill him.
	spawn_link(fun()->timer(5000,Id,{stop_bo}) end),%timer to stop the BO and back to ready
	{next_state,walk,Data};
handle_event(cast,{inter_begin,OtherId,_OtherGender},walk,#{ id := Id , dir := Dir}=Data)->%for begging the inter'
	NewDir=stepBack(Id,Dir,person),			%dont take the next step
	case Res=gen_statem:call(OtherId,{my_rank,read(param,{Id,rank}),read(param,{Id,gender})}) of %checking ranks for the results and send it
		win -> write(param,{Id,rank},read(param,{Id,rank})+1);	%win
		lose->	write(param,{Id,rank},read(param,{Id,rank})-1);	%lose
		{love,_Curr}-> ok; 					%love <3
		_-> ok							%tie
	end,
	spawn_link(fun()->timer(1000,Id,{stop_inter,OtherId,Res}) end),%set timer to stop inter'
	ets:insert(param,{{Id,cv},bo}),					%update
	{next_state,stop,Data#{ dir := NewDir, cv := bo}};		
handle_event({call,From},{my_rank,OtherRank,OtherGender},stop,#{ id := Id}=Data)->%here we doing the real inter'
	MyRank = read(param,{Id,rank}),					%getting curr rank
	{Me,Other}=case {read(param,{Id,gender}),OtherGender} of	%giving the result by my gender and rank
			{X,X} when MyRank>OtherRank -> {win,lose};	%same gender
			{X,X} when MyRank<OtherRank -> {lose,win};	%same gender
			{X,X} -> {tie,tie};				%same gender
			{male,female} when MyRank<OtherRank -> {lose,win};%diffrent gender
			{female,male} when MyRank>OtherRank -> {win,lose};%diffrent gender
			_-> {love,{love,read(param,{Id,curr})}}
			end,
	case Me of							%changing my rank
		win-> write(param,{Id,rank},MyRank+1);
		lose-> write(param,{Id,rank},MyRank-1);
		_-> ok
	end,
	{keep_state,Data,[{reply,From,Other}]}; 
handle_event(cast,{stop_inter,OtherId,Res},stop,#{ id := Id}=Data)->%for stopping the inter' and set the right animation
	case Res of
		{love,Curr}->gen_server:cast(gs,{love,Id,OtherId,Curr,read(param,{Id,curr})});%start love animation
		tie->ok;
		_-> gen_server:cast(gs,{pow,read(param,{Id,curr})})			%start pow animation
	end,
	gen_statem:cast(OtherId,{end_inter}),				%send the other process to back walking
	spawn_link(fun()->checkRank(Id) end),				%check rank
	spawn_link(fun()->timer(5000,Id,{stop_bo}) end),		%set timer for back to ready
	{next_state,walk,Data};
	
%   _____                                 _ 
%  / ____|                               | |
% | |  __   ___  _ __    ___  _ __  __ _ | |
% | | |_ | / _ \| '_ \  / _ \| '__|/ _` || |
% | |__| ||  __/| | | ||  __/| |  | (_| || |
%  \_____| \___||_| |_| \___||_|   \__,_||_|
%-----------------------------------------------                                           

%handle for changing direcation                                          
handle_event(cast,{chngDir,Turn},_,#{dir := Dir}=Data)->
	NewDir = case Dir+Turn of
		9->1;
		0->8;
		X->X
	end,
	{keep_state,Data#{dir := NewDir}};
%handle for the smell raduis and change dir
handle_event(cast,{smell,Dir},_,#{cv := Cv}=Data)->
	case Cv of
		ready-> {keep_state,Data#{dir := Dir}};
		bo->    {keep_state,Data}
	end;
%handle for stop the back off and back to ready
handle_event(cast,{stop_bo},_,#{id := Id}=Data)->
	ets:insert(param,{{Id,cv},ready}),
	{next_state,walk,Data#{cv := ready}};

%handle for when person ask to move to wall, change is direcation according to where he came from
handle_event(cast,{wall,Impact},_,#{dir := Dir , id := Id}=Data)->
	NewDir=stepBack(Id,Dir,Impact),
	io:format("change dir to ~p~n",[NewDir]),
	{keep_state,Data#{dir := NewDir}};
%handle for ignoring steps while back off
handle_event({call,From},step,stop,Data)->
	{keep_state,Data,[{reply,From,ignore}]};
%handle for getting steps and walking in legel way and the right direcation
handle_event({call,From},step,walk,#{dir := Dir, pc := Pc , id := Id , cv := Cv}=Data)->
	{X,Y} = read(param,{Id,curr}),
	{Xoffset,Yoffset} = case Dir of %check direcation and givig X and Y
				1-> {1,0};
				2-> {1,-1};
				3-> {0,-1};
				4-> {-1,-1};
				5-> {-1,0};
				6-> {-1,1};
				7-> {0,1};
				8-> {1,1}
				end,
	New = {X+?STEP_SIZE*Xoffset,Y+?STEP_SIZE*Yoffset},%set the size and the direcation of walking
	Old = {X,Y},
	write(param,{Id,curr},New),
	Gender = read(param,{Id,gender}),	
	gen_server:cast({gs,Pc},{walkreq,Old,New,Id,Cv,Gender,Dir}),%send the pc the move
	{next_state,walk,Data,[{reply,From,ok}]}.
%our terminate func
terminate(_,_,_)->
	io:format("process down~n"),	
	ok.  

%func that after 0.1 sec sending move to person
step(Id)->
	wait(100),
	gen_statem:call(Id,step),
	step(Id).
%timer 
timer(X,Id,RetMsg)->
	receive
		after X -> ok
	end,
	gen_statem:cast(Id,RetMsg).
%change list to atom
toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).
%func for waiting.
wait(X)->
	receive
		after X-> ok
	end.
%func for checking ranks, 10 become 9, 0 is sending to the pc to kill this process
checkRank(Id)->
	case read(param,{Id,rank}) of
		0-> gen_server:cast(gs,{dead,Id,read(param,{Id,curr})});
		10-> write(param,{Id,rank},9);
		_-> ok
	end.
%function for reading and writing to ets.
read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.
write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).
%funcation that change the diraction of person in a random time
changeDir(Id)->
	wait((rand:uniform(3)+2)*1000),
	gen_statem:cast(Id,{chngDir,rand:uniform(3)-2}),
	changeDir(Id).
%steo back func is when process moving and the pc send him that he got some inter' and cant move, so the process back to the old place
stepBack(Id,Dir,Impact)->
	{X,Y} = read(param,{Id,curr}),
	{Xback,Yback}=case Dir of %checking where i was by dir value, if its a wall or person in back off,use snell's law to set the next move
		1->NewDir=5,{-1,0};
		2->case Impact of
			person->NewDir=4;
			up-> NewDir=8;
			right->NewDir=4
			end,{-1,1};
		3->NewDir=7,{0,1};
		4->case Impact of
			person->NewDir=2;
			up->NewDir=6;
			left->NewDir=2
			end,{1,1};	
		5->NewDir=1,{1,0};
		6->case Impact of
			person->NewDir=8;
			down->NewDir=4;
			left->NewDir=8
			end,{1,-1};	
		7->NewDir=3,{0,-1};
		8->case Impact of
			person->NewDir=6;
			down->NewDir=2;
			right->NewDir=6
			end,{-1,-1}
		end,
		New = {X+?STEP_SIZE*Xback,Y+?STEP_SIZE*Yback},%set the "new" move set.
		write(param,{Id,curr},New),
		NewDir.
code_change(_,_,_,_)->ok.
