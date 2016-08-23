%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2009-2013. All Rights Reserved.
%% 
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%% 
%% %CopyrightEnd%

-module(ex_canvas).

-behaviour(wx_object).

%% Client API
-export([start/1]).

%% wx_object callbacks
-export([init/1, terminate/2,  code_change/3,
	 handle_info/2, handle_call/3, handle_cast/2, handle_event/2, handle_sync_event/3]).

-include_lib("wx/include/wx.hrl").

-record(state, 
	{
	  parent,
	  config,
	  canvas,
	  bitmap,
	  overlay,
	  pos
	}).

start(Config) ->
    wx_object:start_link(?MODULE, Config, []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init(Config) ->
    wx:batch(fun() -> do_init(Config) end).

do_init(Config) ->
	Pid=self(),
	register(canvas,Pid),
	
	Div = fun(X,Y)-> X div Y end,
	Multi = fun(X,Y)-> X*Y end,
	%import Pics to ets
	ets:new(pics,[set,named_table]),
	ets:insert(pics,[{bg,imgToBmp("dancefloor2.png",Multi,1)},
			{lightoff,imgToBmp("lightoff.png",Multi,1)},
			{light1,imgToBmp("light1.png",Multi,1)},
			{light2,imgToBmp("light2.png",Multi,1)},
			{light3,imgToBmp("light3.png",Multi,1)},
			{male,imgToBmp("male.png",Div,10)},
			{female,imgToBmp("female.png",Div,10)},
			{h1,imgToBmp("heart1.png",Div,5)},
			{h2,imgToBmp("heart2.png",Div,5)},
			{h3,imgToBmp("heart3.png",Div,5)},
			{h4,imgToBmp("heart4.png",Div,5)},
			{h5,imgToBmp("heart5.png",Div,5)},
			{h6,imgToBmp("heart6.png",Div,5)}]),
		
	
    Parent = proplists:get_value(parent, Config),  
    Panel = wxPanel:new(Parent, []),

    %% Setup sizers
    MainSizer = wxBoxSizer:new(?wxVERTICAL),
    Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, 
				 [{label, ""}]),

    Button = wxButton:new(wx:null(), ?wxID_ANY, [{label, "Start"}]),

    Canvas = wxPanel:new(Panel, [{style, ?wxFULL_REPAINT_ON_RESIZE}]),

    wxPanel:connect(Canvas, paint, [callback]),
    wxPanel:connect(Canvas, size),
    wxPanel:connect(Canvas, left_down),
    wxPanel:connect(Canvas, left_up),
    wxPanel:connect(Canvas, motion),

    wxPanel:connect(Button, command_button_clicked),

    %% Add to sizers
    %wxSizer:add(Sizer, Button, [{border, 5}, {flag, ?wxALL}]),
    wxSizer:addSpacer(Sizer, 5),
    wxSizer:add(Sizer, Canvas, [{flag, ?wxEXPAND},
				{proportion, 1}]),

    wxSizer:add(MainSizer, Sizer, [{flag, ?wxEXPAND},
				   {proportion, 1}]),

    wxPanel:setSizer(Panel, MainSizer),
    wxSizer:layout(MainSizer),

    {W,H} = wxPanel:getSize(Canvas),
    Bitmap = wxBitmap:new(erlang:max(W,30),erlang:max(30,H)),
	
    
    {Panel, #state{parent=Panel, config=Config,
		   canvas = Canvas, bitmap = Bitmap,
		   overlay = wxOverlay:new()
		  }}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sync event from callback events, paint event must be handled in callbacks
%% otherwise nothing will be drawn on windows.
handle_sync_event(#wx{event = #wxPaint{}}, _wxObj,
		  #state{canvas=Canvas, bitmap=Bitmap}) ->
    DC = wxPaintDC:new(Canvas),
    redraw(DC, Bitmap),
    wxPaintDC:destroy(DC),
    ok.

%% Async Events are handled in handle_event as in handle_info
handle_event(#wx{event = #wxCommand{type = command_button_clicked}},
	     State = #state{}) ->
	Pos=lists:flatten([[{{X,Y},Gender}||{{X,Y},{_Pid,Gender}}<-read(location,Pc)]||Pc<-[pc1|[pc2,pc3,pc4]]]),
	print(State,Pos),
    {noreply, State};
handle_event(#wx{event = #wxSize{size={W,H}}},
	     State = #state{bitmap=Prev, canvas=Canvas}) ->
    Bitmap = wxBitmap:new(W,H),
    draw(Canvas, Bitmap, fun(DC) -> wxDC:clear(DC) end),
    wxBitmap:destroy(Prev),
    {noreply, State#state{bitmap = Bitmap}};

handle_event(#wx{event = #wxMouse{type=left_down, x=X, y=Y}}, State) ->
    {noreply, State#state{pos={X,Y}}};

handle_event(#wx{event = #wxMouse{type=left_up}},
	     #state{overlay=Overlay, canvas=Canvas} = State) ->
    DC = wxClientDC:new(Canvas),
    DCO = wxDCOverlay:new(Overlay, DC),
    wxDCOverlay:clear(DCO),
    wxDCOverlay:destroy(DCO),
    wxClientDC:destroy(DC),
    wxOverlay:reset(Overlay),
    {noreply, State#state{pos=undefined}};

handle_event(Ev = #wx{}, State = #state{}) ->
    demo:format(State#state.config, "Got Event ~p\n", [Ev]),
    {noreply, State}.

%% Callbacks handled as normal gen_server callbacks
handle_info(Msg, State) ->
    demo:format(State#state.config, "Got Info ~p\n", [Msg]),
    {noreply, State}.

handle_call(shutdown, _From, State=#state{parent=Panel}) ->
    wxPanel:destroy(Panel),
    {stop, normal, ok, State};
handle_call(Msg, _From, State) ->
    demo:format(State#state.config, "Got Call ~p\n", [Msg]),
    {reply,{error, nyi}, State}.

handle_cast(Msg, State) ->
    io:format("Got cast ~p~n",[Msg]),
    {noreply,State}.

code_change(_, _, State) ->
    {stop, ignore, State}.

terminate(_Reason, #state{overlay=Overlay}) ->
    wxOverlay:destroy(Overlay),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Local functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Buffered makes it all appear on the screen at the same time
draw(Canvas, Bitmap, Fun) ->
    MemoryDC = wxMemoryDC:new(Bitmap),
    Fun(MemoryDC),

    CDC = wxWindowDC:new(Canvas),
    wxDC:blit(CDC, {0,0},
	      {wxBitmap:getWidth(Bitmap), wxBitmap:getHeight(Bitmap)},
	      MemoryDC, {0,0}),    
    wxWindowDC:destroy(CDC),
    wxMemoryDC:destroy(MemoryDC).

redraw(DC, Bitmap) ->
    MemoryDC = wxMemoryDC:new(Bitmap),
    wxDC:blit(DC, {0,0},
	      {wxBitmap:getWidth(Bitmap), wxBitmap:getHeight(Bitmap)},
	      MemoryDC, {0,0}),
    wxMemoryDC:destroy(MemoryDC).

get_pos(W,H) ->
    {random:uniform(W), random:uniform(H)}.

print(State,Positions)->


    {W,H} = wxPanel:getSize(State#state.canvas),
   	
    Fun = fun(DC) ->
		  wxDC:clear(DC),
		  lists:foreach(fun({{X,Y}=Pos,Pic}) ->
					wxDC:drawBitmap(DC,read(pics,Pic),Pos)
				end, [{{0,0},bg},{{350,150},read(param,light)},%add two upper bars]++Positions++[%{{X,Y},name}%add two lower bars])
	  end,
    draw(State#state.canvas, State#state.bitmap, Fun).

imgToBmp(String,Fun,Factor)->
    Image = wxImage:new(String),
    Image2 = wxImage:scale(Image, Fun(wxImage:getWidth(Image),Factor),
			   Fun(wxImage:getHeight(Image),Factor)),
    Bmp = wxBitmap:new(Image2),
    wxImage:destroy(Image),
    wxImage:destroy(Image2),
    Bmp.	

read(Tab,Key)->
	[{Key,Val}]=ets:lookup(Tab,Key),
	Val.
