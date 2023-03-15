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
%% @since 2017-01-05
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a testing of MQTT publish meaasages.

-module(publish).

%%
%% Include files
%%
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
  publish_0/2,
  publish_1/2
]).

-import(testing, [wait_all/1]).

run_test(QoS_subsc, Publisher, Subscriber) ->
	register(test_result, self()),

	F = fun({QoS_recv, #publish{topic= Topic, qos=QoS_pub, dup=_Dup, payload= Msg}} = _Arg) -> 
					 <<QoS_msg:8/integer, _/binary>> = Msg,
%					 ?debug_Fmt("::test:: fun callback: ~100p Q=~p",[_Arg, QoS_msg]),
					 ?assertEqual(QoS_subsc, QoS_recv),
					 Expect_QoS = if QoS_subsc > QoS_msg -> QoS_msg; true -> QoS_subsc end,
					 ?assertEqual(Expect_QoS, QoS_pub),
					 ?assertEqual("AKTest", Topic),
					 test_result ! done 
			end,

	?assertEqual(
		{suback,[QoS_subsc],[]}, 
		mqtt_client:subscribe(Subscriber, [{"AKTest", QoS_subsc, F}])
	),
	Payload = <<") Test Payload QoS = 0. annon. function callback. ">>,
	[ begin 
			Msg = <<Q:8, Payload/binary>>,
			ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = Q}, Msg) 
		end || Q <- [0,1,2]],

	R2 = mqtt_client:subscribe(Subscriber, [{"AKTest", QoS_subsc, {testing, callback}}]), 
	?assertEqual({suback,[QoS_subsc],[]}, R2),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R3),
%% errors:
	R4 = mqtt_client:publish(Publisher, #publish{topic = <<"AK",16#d801:16,"Test">>, qos = 2}, <<"Test Payload QoS = 0.">>), 
%	?assertEqual(ok, R4), %% Erlang server @todo - have to fail!!!
	?assertMatch(#mqtt_client_error{}, R4), %% Mosquitto server

	W = wait_all(4),
	unregister(test_result),
	?assert(W),

	?PASSED
.

publish_0({_, publish}, [Publisher, Subscriber]) -> 
	{"\npublish with QoS = 0,1,2.", 
		timeout, 100, 
		fun() -> 
			[run_test(QoS, Publisher, Subscriber) || QoS <- [0,1,2]]
		end
	}.

publish_1({_QoS, publish}, [Publisher, Subscriber]) -> {"\npublish with QoS = 1", timeout, 100, fun() ->
	register(test_result, self()),

	Payload = <<"Test Payload QoS = 1. annon. function callback. ">>,
	R2_0 = mqtt_client:subscribe(
					Subscriber, 
					[{"AKtest", 
						1, 
						fun(Arg) -> 
							?assertMatch(
								{1,#publish{topic= "AKtest", payload= <<QoS_exp:8, Payload/binary>>, qos= QoS_exp}},
								Arg), 
							test_result ! done
						end
					}]), 
	?assertEqual({suback,[1],[]}, R2_0),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<0:8, Payload/binary>>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<1:8, Payload/binary>>), 
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<1:8, Payload/binary>>), 

	R2 = mqtt_client:subscribe(Subscriber, [{"AKTest", 1, {testing, callback}}]), 
	?assertEqual({suback,[1],[]}, R2),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 0.">>), 

	W = wait_all(4),
	
	unregister(test_result),
	?assert(W),

	?PASSED
end}.
