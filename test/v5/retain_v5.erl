%%
%% Copyright (C) 2015-2023 by krasnop@bellsouth.net (Alexei Krasnopolski)
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

%% @hidden
%% @since 2016-12-19
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT retain meaasages.

-module(retain_v5).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	retain_0/2,
	retain_1/2,
	retain_2/2,
	retain_3/2,
	subscription_option/2,
	subscription_id/2
]).
-import(testing_v5, [wait/4, wait/5]).
%%
%% API Functions
%%
set_handlers(QoS_expected, Topic_expected, Msg_expected) ->
	callback:set_event_handler(onSubscribe, fun(onSubscribe, A) -> ?debug_Fmt("::test:: onSubscribe[1] : ~p~n", [A]), test_result ! done0 end),
	callback:set_event_handler(1, onSubscribe, fun(onSubscribe, A) -> ?debug_Fmt("::test:: onSubscribe[2] : ~p~n", [A]), test_result ! done0 end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish[1] : ~p~n", [A]), test_result ! done1 end),
	callback:set_event_handler(1, onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish[2] : ~p~n", [A]), test_result ! done1 end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! done2 end),
	F = fun(Subs) ->
		fun(onReceive, {Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= Msg}} = Arg) -> 
			?debug_Fmt("::test:: subsc[~p] onReceive : ~p~n", [Subs, Arg]),
			L = size(Msg) - 1,
			<<Msg1:L/binary, QoS_Number:1/bytes>> = Msg,
			?assertEqual(QoS_expected#subscription_options.max_qos, binary_to_integer(QoS_Number)),
			?assertEqual(QoS_expected#subscription_options.max_qos, Q#subscription_options.max_qos),
			?assertEqual(Msg_expected, Msg1),
			?assertEqual(Topic_expected, Topic),
			test_result ! done3
		end
	end,
	callback:set_event_handler(onReceive, F(1)),
	callback:set_event_handler(1, onReceive, F(2)).

retain_0({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=QoS}, "AK_retain_test", <<"Test 0 retain message QoS=">>),

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS}}]), 
	?assert(wait(1,0,0,0)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<"Test 0 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait(0,0,0,1));
		 ?ELSE -> ?assert(wait(0,1,0,1))
	end,
	
	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS}}]), 
	?assert(wait(1,0,0,1)),

	unregister(test_result),
	?PASSED
end}.

%% .
retain_1({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=QoS}, "AK_retain_test", <<"Test 1 retain message QoS=">>),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<"Test 1 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 0",0,0,0,0));
		 ?ELSE -> ?assert(wait("step 0",0,1,0,0))
	end,

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS}}]), 
	?assert(wait("step 1",1,0,0,1)),

	ok = mqtt_client:disconnect(Publisher),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS}}]), 
	?assert(wait("step 2",1,0,0,1)),

	unregister(test_result),
	?PASSED
end}.

retain_2({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=QoS}, "AK_retain_test", <<"Test 2 retain message QoS=">>),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<"Test 2 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 0",0,0,0,0));
		 ?ELSE -> ?assert(wait("step 0",0,1,0,0))
	end,

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=1}}]), %% +1
	?assert(wait("step 1",1,0,0,1)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=1}}]), %% +1
	?assert(wait("step 2",1,0,0,1)),
	
	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=1}}]), %% 0
	?assert(wait("step 3",1,0,0,0)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=0}}]), %% +1
	?assert(wait("step 4",1,0,0,1)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=2}}]), %% 0
	?assert(wait("step 5",1,0,0,0)),

	ok = mqtt_client:unsubscribe(Subscriber1, ["AK_retain_test"]), 
	?assert(wait("step 6",0,0,0,0)),
	ok = mqtt_client:unsubscribe(Subscriber2, ["AK_retain_test"]), 
	?assert(wait("step 7",0,0,0,0)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<>>), %% delete Retain msg
	if QoS == 0 -> ?assert(wait("step 8",0,0,0,0));
		 ?ELSE -> ?assert(wait("step 8",0,1,0,0))
	end,

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=0}}]), %% 0
	?assert(wait("step 9",1,0,0,0)),

	unregister(test_result),
	?PASSED
end}.

retain_3({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, _A) -> test_result ! done0 end),
	callback:set_event_handler(1, onSubscribe, fun(onSubscribe, _A) -> test_result ! done0 end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish : ~p~n", [A]), test_result ! done1 end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! done2 end),
	F = fun(Marker) ->
		fun(onReceive, {Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= Msg, retain = RetainFlag}} = Arg) -> 
			?debug_Fmt("::test:: onReceive subsc[~p] : ~p~n", [Marker, Arg]),
			?assertEqual(QoS, Q#subscription_options.max_qos),
			?assertEqual("AK_retain_test", Topic),
			<<"Test 3 retain message RetainFlag=", MsgRetFl:1/bytes>> = Msg,
			MsgRetainFlag = binary_to_integer(MsgRetFl),
			case Marker of
				1 -> if (MsgRetainFlag == 2) -> ?assertEqual(1, RetainFlag); true -> ?assertEqual(0, RetainFlag) end;
				2 -> if (MsgRetainFlag == 2) -> ?assertEqual(1, RetainFlag); true -> ?assertEqual(MsgRetainFlag, RetainFlag) end
			end,
			test_result ! done3
		end
	end,
	callback:set_event_handler(onReceive, F(1)),
	callback:set_event_handler(1, onReceive, F(2)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<"Test 3 retain message RetainFlag=2">>),
	if QoS == 0 -> ?assert(wait("step 0",0,0,0,0));
		 ?ELSE -> ?assert(wait("step 0",0,1,0,0))
	end,

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=0, retain_as_published=0}}]), 
	?assert(wait("step 1",1,0,0,1)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS,retain_handling=0, retain_as_published=1}}]), 
	?assert(wait("step 2",1,0,0,1)),
	
	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1}, <<"Test 3 retain message RetainFlag=1">>),
	if QoS == 0 -> ?assert(wait("step 3",0,0,0,2));
		 ?ELSE -> ?assert(wait("step 3",0,1,0,2))
	end,

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 0}, <<"Test 3 retain message RetainFlag=0">>),
	if QoS == 0 -> ?assert(wait("step 4",0,0,0,2));
		 ?ELSE -> ?assert(wait("step 4",0,1,0,2))
	end,

	unregister(test_result),
	?PASSED
end}.

subscription_option({QoS, retain} = _X, [_Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(#subscription_options{max_qos=QoS}, "AK_retain_test", <<"Test 4 retain message QoS=">>),

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS, nolocal=0}}]), 
	?assert(wait("step 1",1,0,0,0)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS, nolocal=1}}]), 
	?assert(wait("step 2",1,0,0,0)),
	
	ok = mqtt_client:publish(Subscriber1, #publish{topic = "AK_retain_test", qos = QoS}, <<"Test 4 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 3",0,0,0,2));
		 ?ELSE -> ?assert(wait("step 3",0,1,0,2))
	end,

	ok = mqtt_client:publish(Subscriber2, #publish{topic = "AK_retain_test", qos = QoS}, <<"Test 4 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 4",0,0,0,1));
		 ?ELSE -> ?assert(wait("step 4",0,1,0,1))
	end,

	unregister(test_result),
	?PASSED
end}.

subscription_id({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, _A) -> test_result ! done0 end),
	callback:set_event_handler(1, onSubscribe, fun(onSubscribe, _A) -> test_result ! done0 end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish[1] : ~p~n", [A]), test_result ! done1 end),
	callback:set_event_handler(1, onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish[2] : ~p~n", [A]), test_result ! done1 end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! done2 end),
	F = fun(Marker) ->
		fun(onReceive, {Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= Msg, retain = _RetainFlag, properties = Props}} = Arg) -> 
			?debug_Fmt("::test:: onReceive subsc[~p] : ~p~n", [Marker, Arg]),
			?assertEqual(QoS, Q#subscription_options.max_qos),
			if Marker == 1 -> ?assertEqual(37,proplists:get_value(?Subscription_Identifier, Props, 0));
				 Marker == 2 -> ?assertEqual(38,proplists:get_value(?Subscription_Identifier, Props, 0))
			end,
			?assertEqual("AK_retain_test", Topic),
			<<"Test 1 retain message QoS=", QoS_bin:1/bytes>> = Msg,
			Qos_msg = binary_to_integer(QoS_bin),
			?assertEqual(QoS, Q#subscription_options.max_qos),
			?assertEqual(QoS, Qos_msg),
			test_result ! done3
		end
	end,
	callback:set_event_handler(onReceive, F(1)),
	callback:set_event_handler(1, onReceive, F(2)),

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", #subscription_options{max_qos = QoS}}], [{?Subscription_Identifier, 37}]), 
	?assert(wait("step 1",1,0,0,0)),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", #subscription_options{max_qos = QoS}}], [{?Subscription_Identifier, 38}]), 
	?assert(wait("step 2",1,0,0,0)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS}, <<"Test 1 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 3",0,0,0,2));
		 ?ELSE -> ?assert(wait("step 3",0,1,0,2))
	end,

	ok = mqtt_client:publish(Subscriber2, #publish{topic = "AK_retain_test", qos = QoS}, <<"Test 1 retain message QoS=", (integer_to_binary(QoS))/binary>>),
	if QoS == 0 -> ?assert(wait("step 4",0,0,0,2));
		 ?ELSE -> ?assert(wait("step 4",0,1,0,2))
	end,

	unregister(test_result),
	?PASSED
end}.

