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

-module(topic_alias).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
  publish_0/2,
  publish_1/2,
  publish_2/2,
  publish_3/2
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
		?assertEqual("/AKTest", T),
		test_result ! onReceive 
	end.

publish_0({QoS, publish} = _X, [Publisher, Subscriber] = _Conns) -> {"publish to Topic Alias with QoS = " ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	ok = mqtt_client:subscribe(Subscriber, [{"/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "/AKTest", qos = 0, properties = [{?Topic_Alias, 2}]}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "", qos = 1, properties = [{?Topic_Alias, 2}]}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "/AKTest", qos = 2, properties = []}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.

publish_1({QoS, publish} = _X, [Publisher, Subscriber] = _Conns) -> {"publish to Topic Alias with QoS = " ++ integer_to_list(QoS) ++ ".\n", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	ok = mqtt_client:subscribe(Subscriber, [{"/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Subscriber, #publish{topic = "/AKTest", qos = 0, properties = [{?Topic_Alias, 3}]}, <<"0) Subscriber self publish Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "", qos = 0, properties = [{?Topic_Alias, 3}]}, <<"0) Subscriber self publish Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "/AKTest", qos = 0, properties = [{?Topic_Alias, 2}]}, <<"0) Test Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "", qos = 1, properties = [{?Topic_Alias, 2}]}, <<"1) Test Payload QoS = 1. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "/AKTest", qos = 2, properties = []}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onReceive, onReceive, onReceive, onReceive, onReceive])),

	unregister(test_result),
	?PASSED
end}.

publish_2({QoS, publish} = _X, [_Publisher, Subscriber] = _Conns) -> {"publish to Topic Alias with QoS = " ++ integer_to_list(QoS) ++ ".\n", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),

	ok = mqtt_client:subscribe(Subscriber, [{"/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Subscriber, #publish{topic = "/AKTest", qos = 2, properties = [{?Topic_Alias, 1}]}, <<"2.1) Subscriber self publish Payload QoS = 2. annon. function callback.">>), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "", qos = 2, properties = [{?Topic_Alias, 1}]}, <<"2.2) Subscriber self publish Payload QoS = 2. annon. function callback.">>), 
	?assert(wait_events("", [onReceive, onReceive])),

	callback:set_event_handler(onError, fun(onError, #mqtt_error{} = A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! onError end),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "/AKTest/10", qos = 2, properties = [{?Topic_Alias, 10}]}, <<"2.3) Subscriber self publish Payload QoS = 2. annon. function callback. ">>), 
	ok = mqtt_client:publish(Subscriber, #publish{topic = "/AKTest/11", qos = 2, properties = [{?Topic_Alias, 11}]}, <<"2.4) Subscriber self publish Payload QoS = 2. annon. function callback. ">>), 
%	?assertMatch(#mqtt_error{oper=protocol, errno=148}, R2_4),
	?assert(wait_events("", [onError])),

	gen_server:call(Subscriber, {set_test_flag, skip_alias_max_check}),
	ok = mqtt_client:publish(Subscriber, #publish{topic = "/AKTest/11", qos = 2, properties = [{?Topic_Alias, 11}]}, <<"2.5) Subscriber self publish Payload QoS = 2. annon. function callback. ">>), 
	?assert(wait_events("", [onError])),
 	?assertEqual(false, mqtt_client:is_connected(Subscriber)),

	unregister(test_result),
	?PASSED
end}.

publish_3({QoS, publish} = _X, [Publisher, Subscriber] = _Conns) -> {"publish to empty topic without Topic Alias with QoS = " ++ integer_to_list(QoS) ++ ".\n", timeout, 100, fun() ->
	register(test_result, self()),
	callback:set_event_handler(onSubscribe, fun(onSubscribe, {_,[]} = A) -> ?debug_Fmt("::test:: onSubscribe : ~p~n", [A]), test_result ! onSubscribe end),
	callback:set_event_handler(onReceive, onReceiveCallback(QoS, 0)),
	callback:set_event_handler(onError, fun(onError, #mqtt_error{} = A) -> ?debug_Fmt("::test:: onError : ~p~n", [A]), test_result ! onError end),

	ok = mqtt_client:subscribe(Subscriber, [{"/AKTest", #subscription_options{max_qos = QoS}}]), 
	?assert(wait_events("", [onSubscribe])),

	ok = mqtt_client:publish(Publisher, #publish{topic = "/AKTest", qos = 0, properties = []}, <<"0) Subscriber self publish Payload QoS = 0. annon. function callback. ">>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "", qos = 0, properties = []}, <<"0) Subscriber self publish Payload QoS = 0. annon. function callback. ">>), 
%	?assertMatch(#mqtt_error{oper=protocol,errno=130}, R2_2),
	?assert(wait_events("", [onError, onReceive])),

	unregister(test_result),
	?PASSED
end}.
