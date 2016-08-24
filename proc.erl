-module(proc).
-compile(export_all).
-behaviour(gen_statem).
-define(CB_MODE, handle_event_function).
-define(STEP_SIZE, 3).

start_link(Reg,{{X,Y},Gender,Rank,Dir}=Data,Pc)->
	gen_statem:start_link({local,toAtom(Reg)},proc,[Data,toAtom(Reg),Pc],[]).

init([{{X,Y},Gender,Rank,Dir},Reg,Pc])->
	io:format("started process in ~p~n",[Reg]),
	ets:insert(param,{{Reg,curr},{X,Y}}),
	ets:insert(param,{{Reg,gender},Gender}),
	case Rank of
	-1 -> ets:insert(param,{{Reg,rank},rand:uniform(5)+2});
	_->ets:insert(param,{{Reg,rank},Rank})
	end,
	ets:insert(param,{{Reg,cv},ready}),
	
	Data = #{cv=>ready,dir=>Dir,id=>Reg, pc=>Pc},
	spawn_link(fun()->step(Reg) end),
	{?CB_MODE,walk,Data}.

handle_event(cast,{light,Time},walk,Data)->
	io:format("got light~n"),
	{next_state,stop,Data#{cv := bo}};

handle_event(cast,step,stop,Data)->
	{keep_state,Data};


%handle_event(cast,{inter,Id,Gender},walk,#{dir := Dir , id := Id}=Data)->

	








handle_event(cast,{wall,Impact},walk,#{dir := Dir , id := Id}=Data)->
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
	io:format("change dir tp ~p~n",[NewDir]),
	New = {X+?STEP_SIZE*Xback,Y+?STEP_SIZE*Yback},
	write(param,{Id,curr},New),
	{keep_state,Data#{dir := NewDir}};



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

timer(X,#{id := Id})->
	receive
		after X -> ok
	end,
	gen_statem:cast(Id,{to}).

toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).

wait(X)->
	receive
		after X-> ok
	end.



read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.

write(Tab,Key,Val)->
	ets:insert(Tab,{Key,Val}).
