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
%% @since 2023-02-25
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a testing of MQTT subsription.

-module(subscribe_v5).

%%
%% Include files
%%
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
-include("test.hrl").

-export([
	combined/2,
	subs_filter/2,
	subs_list/2
]).
-import(testing_v5, [wait_all/1]).

%%
%% API Functions
%%

combined(_, Conn) -> {"combined", timeout, 100, fun() ->
	register(test_result, self()),
	ok = mqtt_client:pingreq(Conn, {testing_v5, ping_callback}), 
	
	R2_0 = mqtt_client:subscribe(Conn,
			[{"AKtest", 2, 
				fun(Arg) ->
					?assertMatch({2,
							#publish{
								topic = "AKtest", 
								properties= [
									{?User_Property, {<<"Key">>, <<"Value">>}},
									{?Subscription_Identifier, 21}
								], 
								payload= <<"Test Payload QoS = 0. annon. function callback. ">>}}, 
							Arg
					), 
					test_result ! done 
				end
			}],
			[
				{?Subscription_Identifier, 21},
				{?User_Property, {"Key", "Value"}}
			]
	), 
	?debug_Fmt("::test:: combined->suback : ~p", [R2_0]),
	?assertMatch({suback,[2], _}, R2_0),
	R3_0 = mqtt_client:publish(Conn, #publish{topic = "AKtest", properties = [{?User_Property, {"Key", "Value"}}]},
														 <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),

	timer:sleep(100),
	R2 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {testing_v5, callback}}], []), 
	?assertEqual({suback,[2], []}, R2),
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	ok = mqtt_client:pingreq(Conn, {testing_v5, ping_callback}), 
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1.">>), 
	ok = mqtt_client:pingreq(Conn, {testing_v5, ping_callback}), 
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	ok = mqtt_client:pingreq(Conn, {testing_v5, ping_callback}), 
	timer:sleep(500),
	R9 = mqtt_client:unsubscribe(Conn, ["AKtest"], []), 
	?assertEqual({unsuback, [0], []}, R9),
	ok = mqtt_client:pingreq(Conn, {testing_v5, ping_callback}), 
% does not come
	ok = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 

	W = wait_all(9),
	
	unregister(test_result),
	?assert(W),

	?passed
end}.

subs_list(_, Conn) -> {"subscribtion list", timeout, 100, fun() ->	
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer", 2, {testing_v5, summer_callback}}, {"Winter", 1, {testing_v5, winter_callback}}]), 
	?assertEqual({suback,[2,1],[]}, R2),
	timer:sleep(100),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to winter. QoS = 0.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to summer.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 1}, <<"Sent to winter. QoS = 1.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 

	W = wait_all(4),

	R8 = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"]), 
	?assertEqual({unsuback, [0,0],[]}, R8),
	timer:sleep(100),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	
	W1 = wait_all(1),
	
	unregister(test_result),
	?assert(W),
	?assertNot(W1),

	?PASSED
end}.

subs_filter(_, Conn) -> {"subscription filter", fun() ->	
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer/+", 2, {testing_v5, summer_callback}}, 
																		{"Winter/#", 1, {testing_v5, winter_callback}},
																		{"Spring/+/Month/+", 0, {testing_v5, spring_callback}}
																	 ]), 
	?assertEqual({suback,[2,1,0],[]}, R2),
	timer:sleep(100),
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), %% not delivered 
	ok = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	ok = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 

	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/March/Month/08", qos = 2}, <<"Sent to Spring/March/Month/08. QoS = 2.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/April/Month/01", qos = 1}, <<"Sent to Spring/April/Month/01. QoS = 1.">>),
	ok = mqtt_client:publish(Conn, #publish{topic = "Spring/May/Month/09", qos = 0}, <<"Sent to Spring/May/Month/09. QoS = 0.">>),

	W = wait_all(6),

	R12 = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#", "Spring/+/Month/+"]),
	?assertEqual({unsuback, [0,0,0], []}, R12),
	
	unregister(test_result),
	?assert(W),
	?PASSED
end}.
