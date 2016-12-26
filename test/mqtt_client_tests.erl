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
    {module, mqtt_client_unit_testing},
    { setup, 
      fun testing:do_start/0, 
      fun testing:do_stop/1, 
      {inorder, [
        {"connect", fun connect/0},
        { foreachx, 
          fun testing:do_setup/1, 
          fun testing:do_cleanup/2, 
          [
            {{1, combined}, fun combined/2},
            {{1, subs_list}, fun subs_list/2},
            {{1, subs_filter}, fun subs_filter/2},
            {{1, publish}, fun publish_0/2},
            {{2, publish}, fun publish_1/2},
            {{3, publish}, fun publish_2/2},

						{{1, session}, fun session:session_1/2},
            {{2, session}, fun session:session_1/2},
            {{3, session}, fun session:session_1/2},
            {{4, session}, fun session:session_1/2},

						{{1, session}, fun session:session_2/2},
						{{2, session}, fun session:session_2/2},
						{{3, session}, fun session:session_2/2},
						{{4, session}, fun session:session_2/2},
						{{5, session}, fun session:session_2/2},
						{{6, session}, fun session:session_2/2},
						{{7, session}, fun session:session_2/2},
						{{8, session}, fun session:session_2/2},
 
						{{0, will}, fun will:will_0/2},
 						{{1, will}, fun will:will_0/2},
						{{2, will}, fun will:will_0/2},
						{{1, will_retain}, fun will:will_retain/2}
          ]
        }
      ]}
    }
  ].

connect() ->
	ConnRec = testing:get_connect_rec(),	
	Conn = mqtt_client:connect(
		test_client, 
		ConnRec, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 1. successfully connected : ~p", [Conn]),
	?assert(erlang:is_pid(Conn)),
	
	Conn1 = mqtt_client:connect(
		test_client_1, 
		ConnRec#connect{
			client_id = "test_client_1"
		}, 
		"localhost", 
		3883, 
		[]
	),
%  ?debug_Fmt("::test:: 2. wrong port number : ~120p", [Conn1]),
	?assertMatch(#mqtt_client_error{}, Conn1),
	
	Conn2 = mqtt_client:connect(
		test_client_2, 
		ConnRec#connect{
			client_id = "test_client_2",
			user_name = "quest",
			password = <<"guest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 3. wrong user name : ~120p", [Conn2]),
	?assertMatch(#mqtt_client_error{}, Conn2),
	
	Conn3 = mqtt_client:connect(
		test_client_3, 
		ConnRec#connect{
			client_id = "test_client_3",
			user_name = "guest",
			password = <<"gueest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 4. wrong user password : ~120p", [Conn3]),
	?assertMatch(#mqtt_client_error{}, Conn3),
	
	Conn4 = mqtt_client:connect(
		test_client_4, 
		ConnRec, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 5. duplicate client id: ~p", [Conn4]),
	?assert(erlang:is_pid(Conn4)),
	?assertEqual(disconnected, mqtt_client:status(Conn)),
	
	Conn5 = mqtt_client:connect(
		test_client_5, 
		ConnRec#connect{
			client_id = binary_to_list(<<"test_",255,0,255,"client_5">>),
			user_name = "guest",
			password = <<"guest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 6. wrong utf-8 : ~p", [Conn5]),
	?assert(erlang:is_pid(Conn5)),
%	?assertMatch(#mqtt_client_error{}, Conn5),
	
	Conn6 = mqtt_client:connect(
		test_client_6, 
		ConnRec#connect{
			client_id = "test_client_6",
			user_name = binary_to_list(<<"gu", 0, "est">>),
			password = <<"guest">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 7. wrong utf-8 : ~p", [Conn6]),
	?assertMatch(#mqtt_client_error{}, Conn6),
	
	Conn7 = mqtt_client:connect(
		test_client_7, 
		ConnRec#connect{
			client_id = "test_client_7",
			user_name = "guest",
			password = <<"gu", 0, "est">>
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
%  ?debug_Fmt("::test:: 8. wrong utf-8 : ~p", [Conn7]),
	?assertMatch(#mqtt_client_error{}, Conn7),
	
	?PASSED.

publish_0(_, [Publisher, Subscriber] = _Conns) -> {"publish with QoS = 0", timeout, 100, fun() ->
	register(test_result, self()),

	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKTest", 0, {fun(Arg) -> ?assertMatch({{"AKTest",0},0,<<"Test Payload QoS = 0. annon. function callback. ">>}, Arg), test_result ! done end}}]), 
	?assertEqual({suback,[0]}, R2_0),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 1}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R4_0),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKTest", qos = 2}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R5_0),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKTest", 0, {?MODULE, callback}}]), 
	?assertEqual({suback,[0]}, R2),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R3),
%% errors:
	R4 = mqtt_client:publish(Publisher, #publish{topic = binary_to_list(<<"AK",0,0,0,"Test">>), qos = 2}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R4),

	wait_all(4),
	
	unregister(test_result),

	?PASSED
end}.

publish_1(_, [Publisher, Subscriber] = _Conns) -> {"publish with QoS = 1", timeout, 100, fun() ->
	register(test_result, self()),

	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 1, {fun(Arg) -> ?assertMatch({{"AKtest",1},_,<<"Test Payload QoS = 1. annon. function callback. ">>}, Arg), test_result ! done end}}]), 
	?assertEqual({suback,[1]}, R2_0),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 1. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1. annon. function callback. ">>), 
	?assertEqual(ok, R4_0),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 1. annon. function callback. ">>), 
	?assertEqual(ok, R5_0),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKTest", 1, {?MODULE, callback}}]), 
	?assertEqual({suback,[1]}, R2),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R3),

	wait_all(4),
	
	unregister(test_result),

	?PASSED
end}.

publish_2(_, [Publisher, Subscriber] = _Conns) -> {"publish with QoS = 2", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({{Topic, Q}, QoS, Msg} = _Arg) -> 
					 <<QoS_m:1/bytes, _/binary>> = Msg,
%					 ?debug_Fmt("::test:: fun callback: ~100p Q=~p",[_Arg, binary_to_list(QoS_m)]),
					 ?assertEqual(2, Q),
					 ?assertEqual(list_to_integer(binary_to_list(QoS_m)), QoS),
					 ?assertEqual("AKtest", Topic),
					 test_result ! done 
			end,
	R2_0 = mqtt_client:subscribe(Subscriber, [{"AKtest", 2, {F}}]), 
	?assertEqual({suback,[2]}, R2_0),
	R3_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"0) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),
	R4_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"1) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R4_0),
	R5_0 = mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"2) Test Payload QoS = 2. annon. function callback. ">>), 
	?assertEqual(ok, R5_0),

	R2 = mqtt_client:subscribe(Subscriber, [{"AKTest", 2, {?MODULE, callback}}]), 
	?assertEqual({suback,[2]}, R2),
	R3 = mqtt_client:publish(Publisher, #publish{topic = "AKTest"}, <<"Test Payload QoS = 2.">>), 
	?assertEqual(ok, R3),

	wait_all(4),
	
	unregister(test_result),

	?PASSED
end}.

combined(_, Conn) -> {"combined", timeout, 100, fun() ->
	register(test_result, self()),
%	timer:sleep(1000),
	R1 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R1),
	
	R2_0 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {fun(Arg) -> ?assertMatch({{"AKtest",2},0,<<"Test Payload QoS = 0. annon. function callback. ">>}, Arg), test_result ! done end}}]), 
	?assertEqual({suback,[2]}, R2_0),
	R3_0 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0. annon. function callback. ">>), 
	?assertEqual(ok, R3_0),

	R2 = mqtt_client:subscribe(Conn, [{"AKtest", 2, {?MODULE, callback}}]), 
	?assertEqual({suback,[2]}, R2),
	R3 = mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>), 
	?assertEqual(ok, R3),
	R4 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R4),
	R5 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1.">>), 
	?assertEqual(ok, R5),
	R6 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R6),
	R7 = mqtt_client:publish(Conn, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2.">>), 
	?assertEqual(ok, R7),
	R8 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R8),
	timer:sleep(500),
	R9 = mqtt_client:unsubscribe(Conn, ["AKtest"]), 
	?assertEqual(unsuback, R9),
	R10 = mqtt_client:pingreq(Conn, {?MODULE, ping_callback}), 
	?assertEqual(ok, R10),

	wait_all(9),
	
	unregister(test_result),

	?passed
end}.

subs_list(_, Conn) -> {"subscribtion list", timeout, 100, fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer", 2, {?MODULE, summer_callback}}, {"Winter", 1, {?MODULE, winter_callback}}]), 
	?assertEqual({suback,[2,1]}, R2),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter"}, <<"Sent to winter. QoS = 0.">>), 
	?assertEqual(ok, R3),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer", qos = 1}, <<"Sent to summer.">>), 
	?assertEqual(ok, R5),
	R6 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 1}, <<"Sent to winter. QoS = 1.">>), 
	?assertEqual(ok, R6),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter", qos = 2}, <<"Sent to winter. QoS = 2.">>), 
	?assertEqual(ok, R7),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer", "Winter"]), 
	?assertEqual(unsuback, R9),

	wait_all(3),
	
	unregister(test_result),
	?PASSED
end}.

subs_filter(_, Conn) -> {"subscription filter", fun() ->  
	register(test_result, self()),
	R2 = mqtt_client:subscribe(Conn, [{"Summer/+", 2, {?MODULE, summer_callback}}, {"Winter/#", 1, {?MODULE, winter_callback}}]), 
	?assertEqual({suback,[2,1]}, R2),
	R3 = mqtt_client:publish(Conn, #publish{topic = "Winter/Jan"}, <<"Sent to Winter/Jan.">>), 
	?assertEqual(ok, R3),
	R4 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul/01"}, <<"Sent to Summer/Jul/01.">>), 
	?assertEqual(ok, R4),
	R5 = mqtt_client:publish(Conn, #publish{topic = "Summer/Jul", qos = 1}, <<"Sent to Summer/Jul.">>), 
	?assertEqual(ok, R5),
	R7 = mqtt_client:publish(Conn, #publish{topic = "Winter/Feb/23", qos = 2}, <<"Sent to Winter/Feb/23. QoS = 2.">>), 
	?assertEqual(ok, R7),
	R9 = mqtt_client:unsubscribe(Conn, ["Summer/+", "Winter/#"]), 
	?assertEqual(unsuback, R9),

	wait_all(3),
	
	unregister(test_result),
	?PASSED
end}.

callback({{"AKTest", 0}, QoS, _} = Arg) ->
  case QoS of
		0 -> ?assertMatch({{"AKTest",0},0,<<"Test Payload QoS = 0.">>}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback: ~p",[?MODULE, Arg]),
	test_result ! done;
callback({{"AKTest", 1}, QoS, _} = Arg) ->
  case QoS of
		0 -> ?assertMatch({{"AKTest",1},0,<<"Test Payload QoS = 0.">>}, Arg);
		1 -> ?assertMatch({{"AKTest",1},1,<<"Test Payload QoS = 1.">>}, Arg)
	end,
	test_result ! done;
callback({{"AKTest", 2}, QoS, _} = Arg) ->
  case QoS of
		0 -> ?assertMatch({{"AKTest",2},0,<<"Test Payload QoS = 2.">>}, Arg);
		1 -> ?assertMatch({{"AKTest",2},1,<<"Test Payload QoS = 2.">>}, Arg)
	end,
	test_result ! done;
callback({_, QoS, _} = Arg) ->
  case QoS of
		0 -> ?assertMatch({{"AKtest",2},0,<<"Test Payload QoS = 0.">>}, Arg);
		1 -> ?assertMatch({{"AKtest",2},1,<<"Test Payload QoS = 1.">>}, Arg);
		2 -> ?assertMatch({{"AKtest",2},2,<<"Test Payload QoS = 2.">>}, Arg)
	end,
%	?debug_Fmt("::test:: ~p:callback: ~p",[?MODULE, Arg]),
	test_result ! done.

ping_callback(Arg) ->
%  ?debug_Fmt("::test:: ping callback: ~p",[Arg]),
	?assertEqual(pong, Arg),
	test_result ! done.

summer_callback({{"Summer/Jul", _}, QoS, _} = Arg) ->
	?assertMatch({{"Summer/Jul",2},QoS,<<"Sent to Summer/Jul.">>}, Arg),
	test_result ! done;
summer_callback({_, QoS, _} = Arg) ->
	?assertMatch({{"Summer",2},QoS,<<"Sent to summer.">>}, Arg),
	test_result ! done.

winter_callback({{"Winter/Jan", _}, QoS, _} = Arg) ->
	?assertMatch({{"Winter/Jan",1},QoS,<<"Sent to Winter/Jan.">>}, Arg),
	test_result ! done;
winter_callback({{"Winter/Feb/23", _}, QoS, _} = Arg) ->
	?assertMatch({{"Winter/Feb/23",1},QoS,<<"Sent to Winter/Feb/23. QoS = 2.">>}, Arg),
	test_result ! done;
winter_callback({_, QoS, _} = Arg) ->
	?assertMatch({{"Winter",1},QoS,<<"Sent to winter. QoS = ", _/binary>>}, Arg),
	test_result ! done.
