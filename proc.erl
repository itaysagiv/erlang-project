-module(proc).
-compile(export_all).
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
start_link(Reg,{{X,Y},_Gender,_Rank,_Dir}=Data,Pc)->
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
handle_event(cast,{dance},walk,#{id := Id, cv := ready}=Data)->
	io:format("process ~p received dance~n",[Id]),
	gen_server:cast(gs,{dancing,Id,read(param,{Id,gender}),read(param,{Id,curr})}),
	spawn_link(fun()->timer(5000,Id,{stop_dance}) end),
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{cv := bo}};

handle_event(cast,{dance},_,Data)->
	{keep_state,Data};

handle_event(cast,{stop_dance},stop,#{id := Id}=Data)->
	spawn_link(fun()->timer(3000,Id,{stop_bo}) end),
	{next_state,walk,Data};

%______        _         _     _               
%|  _  \      (_)       | |   (_)              
%| | | | _ __  _  _ __  | | __ _  _ __    __ _ 
%| | | || '__|| || '_ \ | |/ /| || '_ \  / _` |
%| |/ / | |   | || | | ||   < | || | | || (_| |
%|___/  |_|   |_||_| |_||_|\_\|_||_| |_| \__, |
%                                         __/ |
%                                        |___/ 
%----------------------------------------------
handle_event(cast,{bar},walk,#{id := Id, dir := Dir}=Data)->
	Impact = case Dir of
		X when X>=1,X<5 -> up;
		_-> down
		end,
	NewDir = stepBack(Id,Dir,Impact),
	gen_server:cast(gs,{drinking,Id,read(param,{Id,gender}),read(param,{Id,curr})}),
	spawn_link(fun()->timer(3000,Id,{stop_drink}) end),
	MyRank=read(param,{Id,rank}),
	case read(param,{Id,gender}) of
		male-> ets:insert(param,{{Id,rank},MyRank+1});
		female when MyRank/=1-> ets:insert(param,{{Id,rank},MyRank-1});
		_-> ok
	end,
	spawn_link(fun()-> checkRank(Id) end),
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{cv := bo}};

handle_event(cast,{stop_drink},stop,#{id := Id}=Data)->
	spawn_link(fun()->timer(3000,Id,{stop_bo}) end),
	{next_state,walk,Data};

%  _____         _                           _    _               
% |_   _|       | |                         | |  (_)              
%   | |   _ __  | |_  ___  _ __  __ _   ___ | |_  _   ___   _ __  
%   | |  | '_ \ | __|/ _ \| '__|/ _` | / __|| __|| | / _ \ | '_ \ 
%  _| |_ | | | || |_|  __/| |  | (_| || (__ | |_ | || (_) || | | |
% |_____||_| |_| \__|\___||_|   \__,_| \___| \__||_| \___/ |_| |_|
%-------------------------------------------------------------------                                                                 
                                                                 
handle_event(cast,{inter_wait,OtherId,OtherGender},walk,#{dir := Dir , id := Id}=Data)->
	NewDir=stepBack(Id,Dir,person),
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{ dir :=  NewDir, cv := bo}};

handle_event(cast,{end_inter},stop,#{id := Id}=Data)->
	spawn_link(fun()->checkRank(Id) end),
	spawn_link(fun()->timer(5000,Id,{stop_bo}) end),
	{next_state,walk,Data};

handle_event(cast,{inter_begin,OtherId,OtherGender},walk,#{ id := Id , dir := Dir}=Data)->
	NewDir=stepBack(Id,Dir,person),
	case Res=gen_statem:call(OtherId,{my_rank,read(param,{Id,rank}),read(param,{Id,gender})}) of
		win -> write(param,{Id,rank},read(param,{Id,rank})+1);
		lose->	write(param,{Id,rank},read(param,{Id,rank})-1);
		{love,Curr}-> ok;
		_-> ok
	end,
	spawn_link(fun()->timer(1000,Id,{stop_inter,OtherId,Res}) end),
	ets:insert(param,{{Id,cv},bo}),
	{next_state,stop,Data#{ dir := NewDir, cv := bo}};

handle_event({call,From},{my_rank,OtherRank,OtherGender},stop,#{ id := Id}=Data)->
	MyRank = read(param,{Id,rank}),
	{Me,Other}=case {read(param,{Id,gender}),OtherGender} of
			{X,X} when MyRank>OtherRank -> {win,lose};
			{X,X} when MyRank<OtherRank -> {lose,win};
			{X,X} -> {tie,tie};
			{male,female} when MyRank<OtherRank -> {lose,win};
			{female,male} when MyRank>OtherRank -> {win,lose};
			_-> {love,{love,read(param,{Id,curr})}}
			end,
	case Me of
		win-> write(param,{Id,rank},MyRank+1);
		lose-> write(param,{Id,rank},MyRank-1);
		_-> ok
	end,
	{keep_state,Data,[{reply,From,Other}]}; 

handle_event(cast,{stop_inter,OtherId,Res},stop,#{ id := Id}=Data)->
	case Res of
		{love,Curr}->gen_server:cast(gs,{love,Id,OtherId,Curr,read(param,{Id,curr})});
		tie->ok;
		_-> gen_server:cast(gs,{pow,read(param,{Id,curr})})
	end,
	gen_statem:cast(OtherId,{end_inter}),
	spawn_link(fun()->checkRank(Id) end),
	spawn_link(fun()->timer(5000,Id,{stop_bo}) end),
	{next_state,walk,Data};
	
%   _____                                 _ 
%  / ____|                               | |
% | |  __   ___  _ __    ___  _ __  __ _ | |
% | | |_ | / _ \| '_ \  / _ \| '__|/ _` || |
% | |__| ||  __/| | | ||  __/| |  | (_| || |
%  \_____| \___||_| |_| \___||_|   \__,_||_|
%-----------------------------------------------                                           
                                          
handle_event(cast,{chngDir,Turn},_,#{dir := Dir}=Data)->
	NewDir = case Dir+Turn of
		9->1;
		0->8;
		X->X
	end,
	{keep_state,Data#{dir := NewDir}};


handle_event(cast,{stop_bo},_,#{id := Id}=Data)->
	ets:insert(param,{{Id,cv},ready}),
	{next_state,walk,Data#{cv := ready}};


handle_event(cast,{wall,Impact},_,#{dir := Dir , id := Id}=Data)->
	NewDir=stepBack(Id,Dir,Impact),
	io:format("change dir to ~p~n",[NewDir]),
	{keep_state,Data#{dir := NewDir}};

handle_event({call,From},step,stop,Data)->
	{keep_state,Data,[{reply,From,ignore}]};

handle_event({call,From},step,walk,#{dir := Dir, pc := Pc , id := Id , cv := Cv}=Data)->
	{X,Y} = read(param,{Id,curr}),
	
	{Xoffset,Yoffset} = case Dir of
				1-> {1,0};
				2-> {1,-1};
				3-> {0,-1};
				4-> {-1,-1};
				5-> {-1,0};
				6-> {-1,1};
				7-> {0,1};
				8-> {1,1}
				end,
	New = {X+?STEP_SIZE*Xoffset,Y+?STEP_SIZE*Yoffset},
	Old = {X,Y},
	write(param,{Id,curr},New),
	Gender = read(param,{Id,gender}),	
	gen_server:cast({gs,Pc},{walkreq,Old,New,Id,Cv,Gender,Dir}),
	{next_state,walk,Data,[{reply,From,ok}]}.

terminate(_,_,_)->
	io:format("process down~n"),	
	ok.  


step(Id)->
	wait(100),
	gen_statem:call(Id,step),
	step(Id).

timer(X,Id,RetMsg)->
	receive
		after X -> ok
	end,
	gen_statem:cast(Id,RetMsg).

toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).

wait(X)->
	receive
		after X-> ok
	end.

checkRank(Id)->
	case read(param,{Id,rank}) of
		0-> gen_server:cast(gs,{dead,Id,read(param,{Id,curr})});
		10-> write(param,{Id,rank},9);
		_-> ok
	end.

read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).

changeDir(Id)->
	wait((rand:uniform(3)+2)*1000),
	gen_statem:cast(Id,{chngDir,rand:uniform(3)-2}),
	changeDir(Id).

stepBack(Id,Dir,Impact)->
	{X,Y} = read(param,{Id,curr}),
	{Xback,Yback}=case Dir of
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
		New = {X+?STEP_SIZE*Xback,Y+?STEP_SIZE*Yback},
		write(param,{Id,curr},New),
		NewDir.
