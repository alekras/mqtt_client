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
%% @since 2017-01-05
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a testing of MQTT retain meaasages.

-module(publish_v5).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
  publish_0/2,
  publish_1/2,
	publish_2/2
]).

-import(testing_v5, [wait_events/2]).
%%
%% API Functions
%%
onReceiveCallback(QoS, Subscriber) ->
	fun(onReceive, {#subscription_options{max_qos= QOpt}, #publish{qos=Q, topic=T, payload=P, properties=_Props}} = A) -> 
		?debug_Fmt("::test:: onReceive of Subscriber[~p] : ~100p~n", [Subscriber, A]),
		<<QoS_m:1/bytes, _/binary>> = P,
		Msq_QoS = list_to_integer(binary_to_list(QoS_m)),
		?assertEqual(QoS, QOpt),
		Expect_QoS = if QoS > Msq_QoS -> Msq_QoS; true -> QoS end,
		?assertEqual(Expect_QoS, Q),
		?assert(lists:member(T, ["AKtest", "AKTest"])),
%		?assertEqual("AKTest", T),
		test_result ! onReceive 
	end.

publish_0({QoS, publish} = _X, [Publisher, Subscriber] = _Conns) -> {"publish with QoS = " ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	ok = mqtt_client:subscribe(Subscriber, [{"AKTest", #subscription_options{max_qos=QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 1}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onReceive, onReceive, onReceive])),

%% errors:
	callback:set_event_handler(onError, fun(onError, #mqtt_error{} = A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! onError end),
	ok = mqtt_client:publish(Publisher, #publish{topic = <<"AK",16#d802:16,"Test">>, qos = 2}, <<"Test Payload QoS = 0.">>), 
%	?assertEqual(ok, R4), %% Erlang server @todo - have to fail!!!
%	?assertMatch(#mqtt_error{}, R4), %% Mosquitto server
	?assert(wait_events("", [])),%% Erlang server @todo - have to fail!!!

	unregister(test_result),
	?PASSED
end}.

publish_1({QoS, publish} = _X, [Publisher, Subscriber] = _Conns) -> {"publish with QoS = 1", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"0) Test Payload QoS = 0. annon. function callback.">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"1) Test Payload QoS = 0. annon. function callback.">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"2) Test Payload QoS = 0. annon. function callback.">>), 
	?assert(wait_events("", [onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.

%% Test Receive Maximum. Moscitto does not support this feature
publish_2({QoS, publish_rec_max} = _X, [Publisher, Subscriber] = _Conns) -> {"publish with Receive Max.", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),
	callback:set_event_handler(onError, fun(onError, #mqtt_error{} = A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! onError end),

	ok = mqtt_client:subscribe(Subscriber, [{"AKtest", #subscription_options{max_qos=QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	gen_server:call(Publisher, {set_test_flag, skip_send_pubrel}),

	Message = #publish{topic = "AKtest", payload = <<"2) Test Payload QoS = 2. annon. function callback. ">>, qos = 2},
	ok = gen_server:cast(Publisher, {publish, Message}),
	ok = gen_server:cast(Publisher, {publish, Message}),
	ok = gen_server:cast(Publisher, {publish, Message}),

	ok = gen_server:cast(Publisher, {publish, Message}),
	Status = mqtt_client:status(Publisher),
	?debug_Fmt("::test:: ~100p~n",[Status]),
	?assertMatch([{connected,1},{session_present, 0}, _], Status),

	ok = gen_server:cast(Publisher, {publish, Message}),
	?assert(wait_events("",[onError, onError, onError, onError, onError])), %% all 5 - errors
	?assertEqual(false, mqtt_client:is_connected(Publisher)),

	
	unregister(test_result),
	?PASSED
end}.
