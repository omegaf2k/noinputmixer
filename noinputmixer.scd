//151127 windowを簡略化。Slider2Dの数を設定可能に。
//151128 synth1をステップシーケンサーに。GUI実装
//151129 todo synth2をシンセ用シーケンサーに

// todo
// trigger de drone wo mute de beat wo tsukuru
// mophatt:
// 2nd:
// シーケンサー同士の同期、頭リセット

// MIDIClient.init;
// //ポート確認
// MIDIClient.destinations;
//
// m = MIDIOut(1); //UM-2 port1
// m.latency = 0; // this is set to 0.2 by default
//
// a = Pbind(\degree, Prand([1, 2, 3, [0, 2]], inf), \bend, Pwhite(0, 26, inf), \amp, 1);
// // chain a midi event into the pattern and play it (see Pchain)
// (a <> (type: \midi, midiout: m)).play;
//
// s.options.hardwareBufferSize=64;
//
//
//
//
// m.noteOn(1, 40, 127);
// m.control(0,49,0); // Track Mute // ch0=Tr1, 0=Mute解除,0以外でmute
// m = MIDIOut.newByName("IAC ドライバ", "バス 1");
//


// ................ init

var numRows = 6*1; // <-- change size here!!!ステップの縦横サイズ指定
var numCols = 1*16; // <-- and here!!!

var window, decorator, matrix, buttonMatrix, leds;
var synthName, scale, octave, root, transp, sustain, amp;
var player, playButton, control, controlView, sendType;
var midiDevice, popMidiDevice, midiChannel;
var synthList = [\ping, \sine],synthstate;


var screen = ();
var layout = ();
var pointSize = 25;//シーケンサーの１コマのサイズ

s = Server.default;
s.boot;



Window.closeAll;

//matrix window
screen.width = Window.screenBounds.width; //画面サイズ取得
screen.height = Window.screenBounds.height;


// layout stuff
layout.width = numCols * pointSize;
layout.height = numRows * pointSize;
layout.centerPoint = (
	( (screen.width/2) - (layout.width/2) ) @
	( (screen.height/2) - (layout.height/2))
);
layout.button = ((layout.width/numCols)@(layout.height/numRows));
layout.center = Rect( 0, 200, layout.width, layout.height + (layout.button.y+10+pointSize));

// // window
window = Window("MATRIX01", layout.center, resizable:false, border:true).front.alwaysOnTop_(true);
window.view.background_(Color.gray(0.5));
decorator = window.addFlowLayout(0@0, 0@0);

// make arrays
matrix = Array2D.new(numRows, numCols); //シーケンサーのオンオフ状況
buttonMatrix = Array2D.new(numRows, numCols);//ボタン
matrix.postln;
synthstate =Array.fill(6,(0));//シンセの起動状況。全部ゼロで作成
synthstate.postln;

//array初期化
// buttonMatrix.colsDo{ |col, pos|
// 	col.do{ |item, i|
// 		buttonMatrix.at(i, pos).valueAction_(0);
// 	}
// };

//playボタン
Button(window,  Rect(0, 0, layout.button.x*2, layout.button.y) )
.states_([["Play", Color.white, Color.gray],["Stop"]])
	.action_({arg butt;
	if(butt.value == 1,{//~oscsend_1=Synth(\detectSendOSC_1);},{~oscsend_1.free;});
	}
)});

//スペーサー
Button(window,  Rect(0, 0, layout.button.x, layout.button.y))
.states_([["",Color.white,Color.gray]]);

//ランダムボタン

Button(window,  Rect(0, 0, layout.button.x, layout.button.y)  )
	.states_([["R", Color.white, Color.cyan(0.1)]])
	.action_({
		buttonMatrix.colsDo{ |col, pos|
			col.do{ |item, i|
				buttonMatrix.at(i, pos).valueAction_([1,0].wchoose([1,10].normalizeSum));
			}
		}
	});

//　clearボタン
Button(window,  Rect(0, 0, layout.button.x, layout.button.y) )
.states_([["C", Color.white, Color.red(0.5)]])
	.action_({
		buttonMatrix.colsDo{ |col, pos|
			col.do{ |item, i|
				buttonMatrix.at(i, pos).valueAction_(0);
			}
		}
	});

window.view.decorator.nextLine;

// makeLEDS
leds = numCols.collect{ |i|
	Button(window, Rect(0, 0, layout.button.x, layout.button.y))
	.states_([
		["", Color.black, Color.grey],
		["O", Color.black, Color.green(0.7)]
	])
};

StaticText(window, layout.width@10); // separator...

// makebuttons
buttonMatrix.rowsDo{ |row, rowCount|
	row.do{ |item, i|
		matrix.put(rowCount, i, 0);	// init matrix with 0s
		buttonMatrix.put(rowCount, i, Button(window, Rect(0, 0, layout.button.x, layout.button.y))
			.states_([
				["", Color.new255(85, 26, 139), Color.white],
				["F", Color.white, Color.new255(85, 26, 139)]
			])
			.action_({ |v|
				matrix.put(rowCount, i, v.value);
				matrix.postln;
			});
		)
	};
};

/////////////////////////////////
/////trigをoscでクライアントに送る
/////////////////////////////////

(
(
////////////
//trigger1
////////////

//thresholdは1.5まで
//waittimeはdefault 0.04

SynthDef('detectSendOSC_1', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source1;
	source1= AudioIn.ar(1);//FW return 01
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source1), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		1, // Send Trigger ID
		detectsrc // Trigger Value
	);

}).load(s);



~receiveTrigID_1 = 1;

////////////
//trigger2
////////////

SynthDef('detectSendOSC_2', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source2;
	source2= AudioIn.ar(2);//FW return 02
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source2), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		2, // Send Trigger ID
		detectsrc // Trigger Value
	)
}).load(s);


~receiveTrigID_2 = 2;

////////////
//trigger3
////////////

SynthDef('detectSendOSC_3', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source3;
	source3= AudioIn.ar(3);//FW return 03
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source3), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		3, // Send Trigger ID
		detectsrc // Trigger Value
	)
}).load(s);



~receiveTrigID_3 = 3;


////////////
//trigger4
////////////

SynthDef('detectSendOSC_4', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source4;
	source4= AudioIn.ar(4);//FW return 04
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source4), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		4, // Send Trigger ID
		detectsrc // Trigger Value
	)
}).load(s);

~receiveTrigID_4 = 4;




////////////
//trigger5
////////////

SynthDef('detectSendOSC_5', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source5;
	source5= AudioIn.ar(5);//FW return 05
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source5), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		5, // Send Trigger ID
		detectsrc // Trigger Value
	)
}).load(s);

~receiveTrigID_5 = 5;

////////////
//trigger6
////////////

SynthDef('detectSendOSC_6', {
	arg threshold=2.5,waittime=0.8;
	var detectsrc;
	var source6;
	source6= AudioIn.ar(6);//FW return 06
	detectsrc = PV_HainsworthFoote.ar(FFT(LocalBuf(2048),source6), 1.0, 0.0,  threshold, waittime); // Trigger source

	SendTrig.kr(
		Trig1.kr(detectsrc, 1/ControlRate.ir) + Trig1.kr(detectsrc.not, 1/ControlRate.ir) * (Trig1.kr(1, 0.1).not),
		6, // Send Trigger ID
		detectsrc // Trigger Value
	)
}).load(s);

~receiveTrigID_6 = 6;

);

///////////////////////////////////
/////oscを受け取りMIDIOutをトリガー
///////////////////////////////////

(
MIDIClient.init;
//ポート確認
MIDIClient.destinations;
m = MIDIOut(1); //UM-2 port1
m.latency = 0; // this is set to 0.2 by default必ず実行

//
//trigger1 beats
//

~counter =0;
//s.addr, '/tr',
~osctrig_1 = OSCdef(\trig01, { arg msg, time, addr, recvPort;

	//msg.at(3).postln;

	if(msg.at(2) == ~receiveTrigID_1, {
		if(msg.at(3) == 1,{
			//counter
	~counter = ~counter +1;
	~seqcol1 = ~counter % numCols;//stepの現在位置

//MIDIトリガー
//最下段のトラック
//もしArray[~seqcol1]が１なら発音
	if(matrix[numRows-1,~seqcol1] == 1){
		//"kick".postln;
		m.noteOn(16, 36, 127.rand);//octatrack Tr1
	};
	//下から２番目のトラック
	if(matrix[numRows-2,~seqcol1] == 1){
		//"snare".postln;
		m.noteOn(16, 37, 127.rand);//octatrack Tr2
	};

	//下から3番目のトラック
	if(matrix[numRows-3,~seqcol1] == 1){
		//"snare".postln;
		m.noteOn(16, 39, 127.rand);//octatrack Tr4
	};

	//下から4番目のトラック
	if(matrix[numRows-4,~seqcol1] == 1){
		//"snare".postln;
		m.noteOn(16, 41, 127.rand);//octatrack Tr6 arab
	};
	//下から5番目のトラック
	if(matrix[numRows-5,~seqcol1] == 1){
		//"snare".postln;
		m.noteOn(16, 40, 127.rand);//octatrack Tr5 arab
	};


		})
	});


 //	~seqcol1.postln;

//LED点灯切り替え

	if(~seqcol1 != 0){//stepの現在位置が0じゃない場合、一個前のLEDを消灯
		{
			leds[~seqcol1].value_(1);	// turn on actual
			leds[~seqcol1-1].value_(0);	// turn off last
		}.defer;

	}{
		{//stepの現在位置が0の場合
			leds[~seqcol1].value_(1);
			leds.last.value_(0);
		}.defer;
	};





},'/tr',s.addr);

//trigger2 synth
~osctrig_2 = OSCresponderNode(s.addr, '/tr', { arg time, responder, msg;

	if(msg.at(2) == ~receiveTrigID_2, {
		if(msg.at(3) == 1,{
			// On Action
			m.noteOn(2, [72,74,77,79,82,84].choose, 127.rand);
			//"@@@@@@ L-ON @@@@@@".postln;


		})
	})

}).add;


//trigger3 voice
~osctrig_3 = OSCresponderNode(s.addr, '/tr', { arg time, responder, msg;

	if(msg.at(2) == ~receiveTrigID_3, {
		if(msg.at(3) == 1,{
			// On Action
			m.noteOn(16, 40, 127.rand);
			//"@@@@@@ L-ON @@@@@@".postln;


		})
	})

}).add;


//trigger4 evolver
(
~seq = Pseq([59, 62, 61, 57,59], inf);    // repeat foever
~stream = ~seq.asStream;
);

~osctrig_4 = OSCresponderNode(s.addr, '/tr', { arg time, responder, msg;

	if(msg.at(2) == ~receiveTrigID_4, {
		if(msg.at(3) == 1,{
			// On Action
			~seqnote=~stream.next;
			m.noteOn(15, ~seqnote, 127.rand);
			//0.1.wait;
			//m.noteOff(15, ~seqnote);

			//"@@@@@@ L-ON @@@@@@".postln;


		})
	})

}).add;


//trigger5 arab
~osctrig_5 = OSCresponderNode(s.addr, '/tr', { arg time, responder, msg;

	if(msg.at(2) == ~receiveTrigID_5, {
		if(msg.at(3) == 1,{
			// On Action
			m.noteOn(16, 41, 127.rand);
			//"@@@@@@ L-ON @@@@@@".postln;


		})
	})

}).add;




//trigger6 drumfill
~osctrig_6 = OSCresponderNode(s.addr, '/tr', { arg time, responder, msg;

	if(msg.at(2) == ~receiveTrigID_6, {
		if(msg.at(3) == 1,{
			// On Action
			m.noteOn(16, 42, 127.rand);
			//"@@@@@@ L-ON @@@@@@".postln;


		})
	})

}).add;

);


//window
(
~size = 5; //スライダーの数

s.plotTree;
w = Window("noInputTrigger", Rect(100,Window.screenBounds.height - 400, 750, 550));
w.view.decorator = FlowLayout(w.view.bounds);
//ラベル
EZText(w,192@20,initVal:"x=threshold, y=waittime").setColors(Color.grey,Color.grey);

//xとyの値
~valuex = StaticText(w, Rect(45, 10, 200, 20));
~valuex.string = " x = 0";
~valuey = StaticText(w, Rect(45, 10, 200, 20));
~valuey.string = " y = 0";

w.view.decorator.nextLine;

// CompositeViewで枠作成

c = Array.fill(~size, {
	arg i,view;
	view = CompositeView(w,192@220);
	//	.background_(Color.grey);
	view.decorator_(FlowLayout(view.bounds, 5@5, 5@5));
});

//Arrayで番号テキスト作成
Array.fill(~size,{arg i;
	EZText(c[i],20@20,initVal:i+1).setColors(Color.grey,Color.white, Color.new255(211, 211, 211),background:Color.new255(211, 211, 211));});

//再生／停止ボタン
Array.fill(~size,{arg i;
	Button(c[i],60@20)
	.states_([
		["Start"],["Stop"]
		]
	)
	.action_({arg butt;
		//("Button"++(i+1)).postln;
		//butt.value.postln;
		//シンセ起動、ストップ。二重に起動しないように実装。
		if(butt.value==1,
			{
				("synth"++(i+1)++" start").postln;
				switch(i,
					0,{~oscsend_1=Synth(\detectSendOSC_1);},
					1,{~oscsend_2=Synth(\detectSendOSC_2);},
					2,{~oscsend_3=Synth(\detectSendOSC_3);},
					3,{~oscsend_4=Synth(\detectSendOSC_4);},
					4,{~oscsend_5=Synth(\detectSendOSC_5);}
				)
			},
			{
				("synth"++(i+1)++" stop").postln;
				switch(i,
					0,{~oscsend_1.free;},
					1,{~oscsend_2.free;},
					2,{~oscsend_3.free;},
					3,{~oscsend_4.free;},
					4,{~oscsend_5.free;}
				)
		});
	});
});

//説明テキスト
Array.fill(~size,{arg i;
	StaticText(c[i], 80@20)
	.string_(
		switch(i,
			0,{"SEQ"},
			1,{"Mophatt"},
			2,{"Wutan"},
			3,{"Evolver"},
			4,{"Arab"}

		);
	);

});



w.view.decorator.nextLine;

~thred	=	ControlSpec(0.01, 2.5, \exp);
~wait	=	ControlSpec(0.01, 2.5, \exp);

//slider2dをarrayで
Array.fill(~size,{arg i;
	Slider2D(c[i], Rect(0, 0,192, 192))
	.y_(0.05)
	.x_(0.05)
	.background_(Color.rand)
	.knobColor_(Color.rand)
	.action_({|sli|
		switch(i,　//ifの代わりにswitch
			0,{~oscsend_1.set(\threshold,~thred.map(sli.x),\waittime,~wait.map(sli.y));},
			1,{~oscsend_2.set(\threshold,~thred.map(sli.x),\waittime,~wait.map(sli.y));},
			2,{~oscsend_3.set(\threshold,~thred.map(sli.x),\waittime,~wait.map(sli.y));},
			3,{~oscsend_4.set(\threshold,~thred.map(sli.x),\waittime,~wait.map(sli.y));},
			4,{~oscsend_5.set(\threshold,~thred.map(sli.x),\waittime,~wait.map(sli.y));}
		);

		~valuex.string = " x=" ++~thred.map(sli.x);
		~valuey.string = " y=" ++sli.y;
		// [\slider1X, ~thred1.map(sl1.x), \slider1Y, sl1.y].postln;

	});
});

//memo
~memo=StaticText(w, Rect(45, 10, 200, 20));
~memo.string = " Evolver preset 128-4,127-4";
w.front.alwaysOnTop_(true);
);





);

