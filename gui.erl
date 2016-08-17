-module(gui).
-compile(export_all).

start()->
	Server = wx:new(),
	Frame  = wxFrame:new(Server,-1,"Baraka",[{size,{1300,600}}]),
	Img = wxImage:new("index.jpg"),
	Pic = wxImage:create(Img,100,100),
	Sizer = wxSizerItem:new().

tmp()->
	BM = wxBitmap:new(),
	wxBitmap:create(BM,1000,600),
	
	
