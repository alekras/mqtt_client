%%
%% Copyright (C) 2015-2016 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @since 2016-01-03
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module is running erlang unit tests.

-module(mqtt_client_tests).

%%
%% Include files
%%
-include_lib("eunit/include/eunit.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

-export([
  connect/0,
  callback/1, 
  ping_callback/1, 
  summer_callback/1, 
  winter_callback/1]).
-import(testing, [wait_all/1]).
%%
%% API Functions
%%
mqtt_client_test_() ->
  [ 
%       {module, mqtt_client_unit_testing},
    { setup, 
      fun testing:do_start/0, 
      fun testing:do_stop/1, 
      [
        {test, ?MODULE, connect}
%%         { foreachx, 
%%           fun testing:do_setup/1, 
%%           fun testing:do_cleanup/2, 
%%           [
%% %            {{1, open},    fun open/2},
%%             {{2, connect}, fun connect/2},
%%             {{3, subs_list}, fun subs_list/2},
%%             {{4, subs_filter}, fun subs_filter/2}
%%           ]
%%         }
      ]
    }
  ].

connect() ->
  ?debug_Fmt("::test:: connect/0:", []),
	Conn = mqtt_client:connect(
		test_client, 
		#connect{
			client_id = "test_client",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		2883, 
		[]
	),
  ?debug_Fmt("::test:: connect/0: ~p", [Conn]),
	?assert(erlang:is_pid(Conn)),
	
	Conn1 = mqtt_client:connect(
		test_client_1, 
		#connect{
			client_id = "test_client_1",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		3883, 
		[]
	),
  ?debug_Fmt("::test:: connect/0: ~p", [Conn1]),
	?assertMatch(#mqtt_client_error{}, Conn1),
	
	Conn2 = mqtt_client:connect(
		test_client_1, 
		#connect{
			client_id = "test_client",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		2883, 
		[]
	),
  ?debug_Fmt("::test:: connect/0: ~p", [Conn2]),
	?assert(erlang:is_pid(Conn2)),
	?assertEqual(disconnected, mqtt_client:status(Conn)),
	
	?PASSED.

connect(_, Conn) -> {timeout, 100, fun() ->
	register(test_result, self()),
	timer:sleep(1000),
	R1 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 1st pingreq returns: ~p",[R1]),

	R2_0 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {fun(Arg) -> ?debug_Fmt("::test:: callback: ~p",[Arg]), test_result ! done end}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2_0]),
	R3_0 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3_0]),

	R2 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {?MODULE, callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R4 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 2nd pingreq returns: ~p",[R4]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R6 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 3rd pingreq returns: ~p",[R6]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	R8 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 4th pingreq returns: ~p",[R8]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["AKtest"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	R10 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?debug_Fmt("::test:: 5th pingreq returns: ~p",[R10]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(9) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),

	?PASSED
end}.

subs_list(_, Conn) -> {timeout, 100, fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer", 2, {?MODULE, summer_callback}}, {"Winter", 1, {?MODULE, winter_callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to winter.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to summer.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(3) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),
	?PASSED
end}.

subs_filter(_, Conn) -> fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer/+", 2, {?MODULE, summer_callback}}, {"Winter/#", 1, {?MODULE, winter_callback}}]), 
	?debug_Fmt("::test:: subscribe returns: ~p",[R2]),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R3]),
	R4 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), 
	?debug_Fmt("::test:: publish (QoS = 0) returns: ~p",[R4]),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	?debug_Fmt("::test:: publish (QoS = 1)  returns: ~p",[R5]),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 
	?debug_Fmt("::test:: publish (QoS = 2)  returns: ~p",[R7]),
	timer:sleep(1000),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#"]), 
	?debug_Fmt("::test:: unsubscribe returns: ~p",[R9]),
	timer:sleep(1000),
%	R12 = mqtt_client:disconnect(Conn), 
%	?debug_Fmt("::test:: disconnect returns: ~p",[R12]),

	case wait_all(3) of
		ok -> ?debug_Fmt("::test:: all done received.",[]);
		fail -> ?assert(false)
	end,
	
	case wait_all(1) of
		fail -> ?debug_Fmt("::test:: no done received.",[]);
		ok -> ?assert(false)
	end,
	
	unregister(test_result),
	?PASSED
end.

callback(Arg) ->
  ?debug_Fmt("::test:: callback: ~p",[Arg]),
	test_result ! done.

ping_callback(Arg) ->
  ?debug_Fmt("::test:: ping callback: ~p",[Arg]),
	test_result ! done.

summer_callback(Arg) ->
  ?debug_Fmt("::test:: summer_callback: ~p",[Arg]),
	test_result ! done.

winter_callback(Arg) ->
  ?debug_Fmt("::test:: winter_callback: ~p",[Arg]),
	test_result ! done.
