-module(proc).
-compile(export_all).
-behaviour(gen_statem).
-define(CB_MODE, handle_event_function).

start_link(Reg,{{X,Y},Gender,Rank}=Data)->
	gen_statem:start_link({local,toAtom(Reg)},proc,[Data,toAtom(Reg)],[]).

init([{{X,Y},Gender,Rank},Reg])->
	io:format("started process in ~p~n",[Reg]),
	%ets:insert(param,{{Reg,curr},{X,Y}}),
	%ets:insert(param,{{Reg,gender},Gender}),
	%case Rank of
	%-1 -> ets:insert(param,{{Reg,rank},rand:uniform(5)+2});
	%_->ets:insert(param,{{Reg,rank},Rank})
	%end,
	%ets:insert(param,{{Reg,cv},ready}),
	Dir = rand:uniform(8),
	Data = #{cv=>ready,dir=>Dir,reg=>Reg},
	{?CB_MODE,walk,Data}.

handle_event(cast,{light,Time},walk,Data)->
	io:format("got light~n"),
	{next_state,stop,Data#{cv := bo}}.
	


step(#{reg := Reg , cv := Cv})->
	

timer(X,#{reg := Reg})->
	receive
		after X -> ok
	end,
	gen_statem:cast(Reg,{to}).

toAtom(Term)->
	list_to_atom(lists:flatten(io_lib:format("~p", [Term]))).
