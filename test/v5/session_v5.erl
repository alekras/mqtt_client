%%
%% Copyright (C) 2015-2022 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @since 2016-09-29
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT session.

-module(session_v5).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	session_1/2,
	session_2/2,
	session_expire/2,
	msg_expire/2
]).
-import(testing_v5, [wait_all/1]).
%%
%% API Functions
%%

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_1({1, session}, [Publisher, Subscriber]) -> {"session QoS=1, publisher skips send publish.", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, F}]), 
	?assertEqual({suback,[1],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 

	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"2) Test Payload QoS = 1. annon. function callback. ">>), 
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","puback timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(2),
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Publisher: skip recieve publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({2, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, publisher skips recieve puback.", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, F}]), 
%	?debug_Fmt("::test:: subscribe returns: ~p",[R1_0]),
	?assertEqual({suback,[1],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R2_0]),
	?assertEqual(ok, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_rcv_puback}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
%	?debug_Fmt("::test:: publish (QoS = 1) returns: ~120p",[R3_0]),
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","puback timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher, 
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip recieve publish. Resend publish after reconnect and restore session. Duplicate message.
session_1({3, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips receive publish", timeout, 100, fun() ->
%  ?debug_Fmt("::test:: session_1 : ~p ~p", [_X, _Conns]),
	register(test_result, self()),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, F}]), 
	?assertEqual({suback,[1],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	timer:sleep(1000), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	timer:sleep(1000), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		{F}, 
		[]
	),
	?debug_Fmt("::test:: Subscriber with saved session : ~p", [Subscriber]),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	
	W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip send publish ack. Resend publish after reconnect and restore session. Duplicate message.
session_1({4, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=1, subscriber skips send puback.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, F}]), 
	?assertEqual({suback,[1],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::1 Test Payload QoS = 1. function callback. ">>), 
	?assertEqual(ok, R2_0),
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_send_puback}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::2 Test Payload QoS = 1. function callback. ">>), 
	?assertEqual(ok, R3_0),
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"::3 Test Payload QoS = 1. function callback. ">>), 
	
  W = wait_all(4),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end}.

%% Publisher: skip send publish. Resend publish after reconnect and restore session.
session_2({5, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips send publish.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?assertEqual(2, Q),
					 ?assertEqual("AKTest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKTest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_send_publish}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","pubcomp timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Publisher: skip receive pubrec. Resend publish after reconnect and restore session.
session_2({6, session} = _X, [Publisher, Subscriber] = _Conns) -> {"session QoS=2, publisher skips receive pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?assertEqual(2, Q),
					 ?assertEqual("AKTest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKTest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assertEqual(ok, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubrec}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback.">>), 
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","pubcomp timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Publisher: skip send pubrel. Resend pubrel after reconnect and restore session.
session_2({7, session}, [Publisher, Subscriber]) -> {"session QoS=2, publisher skips send pubrel.", timeout, 100, fun() ->
	register(test_result, self()),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKTest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKTest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R2_0),
	
	gen_server:call(Publisher, {set_test_flag, skip_send_pubrel}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","pubcomp timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Publisher: skip receive pubcomp. Resend publish after reconnect and restore session.
session_2({8, session}, [Publisher, Subscriber]) -> {"session QoS=2, publisher skips receive pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKTest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKTest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R2_0),
	gen_server:call(Publisher, {set_test_flag, skip_rcv_pubcomp}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual({mqtt_client_error,publish,none,"mqtt_client:publish/2","pubcomp timeout"}, R3_0),
	mqtt_client:disconnect(Publisher),
	gen_server:call(Publisher, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Publisher,
		(testing_v5:get_connect_rec(publisher))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	
  W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Publisher),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip receive publish. Resend publish after reconnect and restore session.
session_2({9, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips receive publish.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assertEqual(ok, R2_0),
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_rcv_publish}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assertEqual(ok, R3_0),
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	timer:sleep(50),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
%	?debug_Fmt("::test:: after connection: ~100p",[Subscriber_2]),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 

	W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session.
session_2({10, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 

	W = wait_all(4),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip receive pubrel. Resend publish after reconnect and restore session.
session_2({11, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips receive pubrel.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assertEqual(ok, R2_0),
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_rcv_pubrel}),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	?assertEqual(ok, R3_0),
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 

	W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip send pubcomp. Resend publish after reconnect and restore session.
session_2({12, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubcomp.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_send_pubcomp}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	timer:sleep(500), %%  
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 1000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"::3 Test Payload QoS = 2. function callback. ">>), 

	W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end}.

session_expire({1, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is not expired.", timeout, 100, fun() ->
	register(test_result, self()),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 16#FFFFFFFF}]
			}, 
		[]
	),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive a message 
	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(500), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	R3_0 = mqtt_client:status(Subscriber),
	?assertMatch([_, {session_present, 1}, _], R3_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 

	W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

session_expire({2, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is ended.", timeout, 100, fun() ->
	register(test_result, self()),
	CallBack = fun({Q, _} = Arg) -> 
							?debug_Fmt("::test:: fun Callback for disconnect: ~100p",[Arg]),
							?assertEqual(130,Q),
							test_result ! done 
						end,
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 0}]
			}, 
		[]
	),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive a message 
	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(500), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		CallBack,
		[]
	),
	?assert(is_pid(Subscriber)),
	R3_0 = mqtt_client:status(Subscriber),
	?assertMatch([_, {session_present, 0}, _], R3_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 

	timer:sleep(500), %%  
	ok = mqtt_client:disconnect(Subscriber,0,[{?Session_Expiry_Interval, 5}]),
	
 W = wait_all(2),
	
	unregister(test_result),
	?assert(W),
	?PASSED
end};

session_expire({3, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is expire in 1 minutes.", timeout, 100, fun() ->
	register(test_result, self()),
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 60}] %% in seconds
			}, 
		[]
	),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive a message 
	ok = mqtt_client:disconnect(Subscriber),
	timer:sleep(500), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	R3_0 = mqtt_client:status(Subscriber),
	?assertMatch([_, {session_present, 1}, _], R3_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 

	timer:sleep(500), %%  
	mqtt_client:disconnect(Subscriber),
	
 W = wait_all(2),
	
	unregister(test_result),
	?assert(W),
	?PASSED
end};

session_expire({4, session_expire}, [Subscriber]) -> {"session QoS=2, subscriber session is expire in 1 minutes.", timeout, 100, fun() ->
	register(test_result, self()),
	ok = mqtt_client:connect(
		Subscriber,
		(testing_v5:get_connect_rec(subscriber))#connect{
				keep_alive = 60000,
				clean_session = 1,
				properties = [{?Session_Expiry_Interval, 10}] %% in seconds
			}, 
		[]
	),

	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	R2_0 = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::1 Test Payload QoS = 2. function callback. ">>), 
	?assertEqual(ok, R2_0),
	timer:sleep(500), %% allow subscriber to receive a message 
	R2_1 = mqtt_client:disconnect(Subscriber),
	?assertEqual(ok, R2_1),
	timer:sleep(20000), %%  
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	R3_0 = mqtt_client:status(Subscriber),
	?assertMatch([_, {session_present, 0}, _], R3_0),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "AKtest", qos = 2}, <<"::2 Test Payload QoS = 2. function callback. ">>), 

	timer:sleep(500), %%  
	mqtt_client:disconnect(Subscriber),
	
 W = wait_all(1),
	
	unregister(test_result),
	?assert(W),
	?PASSED
end}.

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session. Testing message Expiry interval.
msg_expire({1, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec to test message expiry interval", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2, properties=[{?Message_Expiry_Interval, 5}]}, <<"::1 Test message expiry interval, QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2, properties=[{?Message_Expiry_Interval, 5}]}, <<"::2 Test message expiry interval, QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	
  W = wait_all(3),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end};

%% Subscriber: skip send pubrec. Resend publish after reconnect and restore session. Testing message Expiry interval.
msg_expire({2, session}, [Publisher, Subscriber]) -> {"session QoS=2, subscriber skips send pubrec to test message expiry interval", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= _Msg}} = _Arg) -> 
					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q#subscription_options.max_qos),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=2}, F}]), 
	?assertEqual({suback,[2],[]}, R1_0),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2, properties=[{?Message_Expiry_Interval, 5}]}, <<"::1 Test message expiry interval, QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive first message 
	gen_server:call(Subscriber, {set_test_flag, skip_send_pubrec}),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2, properties=[{?Message_Expiry_Interval, 5}]}, <<"::2 Test message expiry interval, QoS = 2. function callback. ">>), 
	timer:sleep(500), %% allow subscriber to receive second message 
	mqtt_client:disconnect(Subscriber),
	gen_server:call(Subscriber, {set_test_flag, undefined}),
	timer:sleep(10000), %% allow message to expire 
	ok = mqtt_client:connect(
		Subscriber, 
		(testing_v5:get_connect_rec(subscriber))#connect{clean_session = 0, keep_alive = 60000}, 
		[]
	),
	?assert(is_pid(Subscriber)),
	
  W = wait_all(2),
	
	unregister(test_result),
	mqtt_client:disconnect(Subscriber),
	?assert(W),
	?PASSED
end}.

