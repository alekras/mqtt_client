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
%% @since 2016-09-29
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT will.

-module(will).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
  will_a/2,
  will_0/2,
	will_retain/2
]).
-import(testing, [wait_all/1]).
%%
%% API Functions
%%
set_handlers(QoS_expected, Topic_expected, Msg_expected) ->
	callback:set_event_handler(onSubscribe, fun(onSubscribe, _A) -> test_result ! done end),
	callback:set_event_handler(onPublish, fun(onPublish, A) -> ?debug_Fmt("::test:: onPublish : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onError, fun(onError, A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! done end),
	callback:set_event_handler(onReceive, 
				fun(onReceive, {Q, #publish{topic= Topic, qos=_QoS, dup=_Dup, payload= Msg}} = Arg) -> 
					?debug_Fmt("::test:: onReceive : ~p~n", [Arg]),
					 ?assertEqual(QoS_expected, Q),
					 ?assertEqual(Topic_expected, Topic),
					?assertEqual(Msg_expected, Msg),
					 test_result ! done 
				end).

will_a({0, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=0.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(undefined, "AK_will_test", <<"Test will message">>),

	ok = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 0}]), 
	?assert(wait_all(1)),
%% generate connection close:
	ok = mqtt_client:disconnect(Publisher),

	?assert(wait_all(0)),

	unregister(test_result),

	?PASSED
end}.

will_0({0, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=0.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(undefined, "AK_will_test", <<"Test will message">>),

	ok = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 0}]), 
	?assert(wait_all(1)),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>)
	catch
		_:_ -> ok
	end,

	?assert(wait_all(1)),

	unregister(test_result),
	?PASSED
end};

will_0({1, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=1.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(undefined, "AK_will_test", <<"Test will message">>),

	ok = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 1}]), 
	?assert(wait_all(1)),
% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1. annon. function callback. ">>)	
	catch
		_:_ -> ok
	end,

	?assert(wait_all(1)),

	unregister(test_result),
	?PASSED
end};

will_0({2, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=2.", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(undefined, "AK_will_test", <<"Test will message">>),

	ok = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 2}]), 
	?assert(wait_all(1)),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>)
	catch
		_:_ -> ok
	end,

	?assert(wait_all(1)),

	unregister(test_result),
	?PASSED
end}.

will_retain({QoS, will_retain} = _X, [Publisher, Subscriber] = _Conns) -> {"will with retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(undefined, "AK_will_retain_test", <<"Test will retain message">>),

	ok = mqtt_client:subscribe(Subscriber, [{"AK_will_retain_test", QoS}]), 
	?assert(wait_all(1)),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = QoS}, <<"Test Payload QoS = 2. annon. function callback. ">>)
	catch
		_:_ -> ok
	end,
	?assert(wait_all(1)),

	Subscriber_2 = mqtt_client:create(subscriber2),
	ok = mqtt_client:connect(
		Subscriber_2, 
		?CONN_REC(subscriber2)#connect{clean_session = 1}, 
		{callback, call},
		[]
	),
	?assert(is_pid(Subscriber_2)),
	timer:sleep(500),
%%	?assert(wait_all(1)),
	ok = mqtt_client:subscribe(Subscriber_2, [{"AK_will_retain_test", QoS}]), 
	?assert(wait_all(2)),

	unregister(test_result),
	mqtt_client:dispose(Subscriber_2),
	?PASSED
end}.
