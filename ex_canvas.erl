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
-export([start/1,get_pos/2]).

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
	  pos,
	  menu
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
	ets:insert(pics,[{bg,imgToBmp("dancefloor.png",Multi,1)},
			{lightoff,imgToBmp("lightoff.png",Multi,1)},
			{light1,imgToBmp("light1.png",Multi,1)},
			{light2,imgToBmp("light2.png",Multi,1)},
			{light3,imgToBmp("light3.png",Multi,1)},
			{drink1female,imgToBmp("drink1female.png",Div,1)},
			{drink2female,imgToBmp("drink2female.png",Div,1)},
			{drink1male,imgToBmp("drink1male.png",Div,1)},
			{drink2male,imgToBmp("drink2male.png",Div,1)},
			{d1male,imgToBmp("dance1male.png",Div,1)},
			{d2male,imgToBmp("dance2male.png",Div,1)},
			{d3male,imgToBmp("dance3male.png",Div,1)},
			{d4male,imgToBmp("dance4male.png",Div,1)},
			{d1female,imgToBmp("dance1female.png",Div,1)},
			{d2female,imgToBmp("dance2female.png",Div,1)},
			{d3female,imgToBmp("dance3female.png",Div,1)},
			{d4female,imgToBmp("dance4female.png",Div,1)},
			{dark,imgToBmp("dark.png",Div,2)},
			{h1,imgToBmp("heart1.png",Div,5)},
			{h2,imgToBmp("heart2.png",Div,5)},
			{h3,imgToBmp("heart3.png",Div,5)},
			{h4,imgToBmp("heart4.png",Div,5)},
			{h5,imgToBmp("heart5.png",Div,5)},
			{h6,imgToBmp("heart6.png",Div,5)},

			{tbr,imgToBmp("bartopRIGHT.png",Multi,1)},
			{tbl,imgToBmp("bartopLEFT.png",Multi,1)},
			{bbr,imgToBmp("barbotRIGHT.png",Multi,1)},
			{bbl,imgToBmp("barbotLEFT.png",Multi,1)},

			{pow1,imgToBmp("pow1.png",Div,3)},
			{pow2,imgToBmp("pow2.png",Div,3)},
			{pow3,imgToBmp("pow3.png",Div,3)},
			{pow4,imgToBmp("pow4.png",Div,3)},
			{pow5,imgToBmp("pow5.png",Div,3)},

			{'1',imgToBmp("1.png",Div,10)},
			{'2',imgToBmp("2.png",Div,10)},
			{'3',imgToBmp("3.png",Div,10)},
			{'4',imgToBmp("4.png",Div,10)},
			{'5',imgToBmp("5.png",Div,10)},
			{'6',imgToBmp("6.png",Div,10)},
			{'7',imgToBmp("7.png",Div,10)},
			{'8',imgToBmp("8.png",Div,10)},
			{'9',imgToBmp("9.png",Div,10)},

			{female1r,imgToBmp("walk1femaleRIGHT.png",Div,1)},
			{female1l,imgToBmp("walk1femaleLEFT.png",Div,1)},
			{female2r,imgToBmp("walk2femaleRIGHT.png",Div,1)},
			{female2l,imgToBmp("walk2femaleLEFT.png",Div,1)},
			{female3r,imgToBmp("walk3femaleRIGHT.png",Div,1)},
			{female3l,imgToBmp("walk3femaleLEFT.png",Div,1)},
			{female4r,imgToBmp("walk4femaleRIGHT.png",Div,1)},
			{female4l,imgToBmp("walk4femaleLEFT.png",Div,1)},

			{male1r,imgToBmp("walk1maleRIGHT.png",Div,1)},
			{male1l,imgToBmp("walk1maleLEFT.png",Div,1)},
			{male2r,imgToBmp("walk2maleRIGHT.png",Div,1)},
			{male2l,imgToBmp("walk2maleLEFT.png",Div,1)},
			{male3r,imgToBmp("walk3maleRIGHT.png",Div,1)},
			{male3l,imgToBmp("walk3maleLEFT.png",Div,1)},
			{male4r,imgToBmp("walk4maleRIGHT.png",Div,1)},
			{male4l,imgToBmp("walk4maleLEFT.png",Div,1)},

			
			{standMale,imgToBmp("male.png",Div,1)},
			{standFemale,imgToBmp("female.png",Div,1)}
			]),
			
		
	
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
	
    PopupMenu = create_menu(),

    {Panel, #state{parent=Panel, config=Config,
		   canvas = Canvas, bitmap = Bitmap,
		   overlay = wxOverlay:new(), menu=PopupMenu
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
	Pos=lists:flatten([[entry(X,Y,Gender,Pc)||{{X,Y},{_Id,Gender}}<-read(location,Pc)]||Pc<-[pc1|[pc2,pc3,pc4]]]),
	Ranks =lists:flatten([read(ranks,Pc)||Pc<-[pc1|[pc2,pc3,pc4]]]),
	%io:format("~p~n",[ets:tab2list(walk_pics)]),
	print(State,Pos,Ranks),
    {noreply, State};
handle_event(#wx{event = #wxSize{size={W,H}}},
	     State = #state{bitmap=Prev, canvas=Canvas}) ->
    Bitmap = wxBitmap:new(W,H),
    draw(Canvas, Bitmap, fun(DC) -> wxDC:clear(DC) end),
    wxBitmap:destroy(Prev),
    {noreply, State#state{bitmap = Bitmap}};

handle_event(#wx{obj = _Menu, id = Id,
		 event = #wxCommand{type = command_menu_selected}},
	     State = #state{pos={X,Y}}) ->
    %% Get the selected item label
    case Id of
	1->	gen_server:cast(gs,{menu_create,male,{X,Y}});
	2->	gen_server:cast(gs,{menu_create,female,{X,Y}});
	3->	gen_server:cast(gs,{menu_random});
	4->	gen_server:cast(gs,{menu_light})
	end,
    {noreply, State};

handle_event(#wx{obj=Panel,event = #wxMouse{type=left_down, x=X, y=Y}}, State=#state{menu=Menu}) ->
	wxWindow:popupMenu(Panel, Menu),
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

entry(X,Y,Gender,Pc) when Gender==male ; Gender==female->
	L=read(walk_pics,Pc),
	List = [V||{K,V}<-L,K=={X,Y}],
	case List of
	[]-> Num=0,_Gen=Gender,Dir=1;
	[{Num,_Gen,Dir}]-> ok
	end,
	case Gender of
		male->
			case {Num,Dir} of	
				{0,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},male1r};
				{0,_}				-> {{X,Y},male1l};
				{1,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},male2r};
				{1,_}				-> {{X,Y},male2l};
				{2,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},male3r};
				{2,_}				-> {{X,Y},male3l};
				{3,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},male4r};
				{3,_}				-> {{X,Y},male4l}
			end;
		female-> 	
			case {Num,Dir} of	
				{0,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},female1r};
				{0,_}				-> {{X,Y},female1l};
				{1,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},female2r};
				{1,_}				-> {{X,Y},female2l};
				{2,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},female3r};
				{2,_}				-> {{X,Y},female3l};
				{3,_} when Dir==8;Dir==1;Dir==2;Dir==3 	-> {{X,Y},female4r};
				{3,_}				-> {{X,Y},female4l}
			end
	end;
entry(X,Y,Gender,_)->
	{{X,Y},Gender}.

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
    {rand:uniform(W), rand:uniform(H)}.

print(State,Positions,Ranks)->


    {_W,_H} = wxPanel:getSize(State#state.canvas),
   	
    Fun = fun(DC) ->
		  wxDC:clear(DC),
		  lists:foreach(fun({{_X,_Y}=Pos,Pic}) ->
					wxDC:drawBitmap(DC,read(pics,Pic),Pos)
				end,[{{0,0},bg},{{0,0},tbl},{{604,0},tbr},{{350,100},read(param,light)}]++sortByY(Positions)++sortByY(Ranks)++[{{0,345},bbl},{{604,345},bbr}])
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
	[{Key,Val}|_T]=ets:lookup(Tab,Key),
	Val.

sortByY([])->[];
sortByY(List)->
	[{{X2,Y2},Data2}||{{Y2,X2},Data2}<-lists:sort([{{Y1,X1},Data1}||{{X1,Y1},Data1}<-List])].

create_menu() ->
	io:format("menu created~n"),
    Menu = wxMenu:new([]),
    wxMenu:append(Menu, 1, "Create Male", []),
    wxMenu:append(Menu, 2, "Create Female", []),
    wxMenu:appendSeparator(Menu),
    wxMenu:append(Menu, 3, "Create 5 Random", []),
    wxMenu:appendSeparator(Menu),
    wxMenu:append(Menu, 4, "light", []),

   _Bitmap = wxArtProvider:getBitmap("wxART_NEW"),

    wxMenu:connect(Menu, command_menu_selected),
    Menu.
