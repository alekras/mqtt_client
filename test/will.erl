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
%% @since 2016-09-29
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc This module implements a tesing of MQTT session.

-module(will).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

-export([
  will_0/2
]).
-import(testing, [wait_all/1]).
%%
%% API Functions
%%

%% .
will_0({0, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=0.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(0, Q),
					 ?assertEqual("AK_will_test", Topic),
					 ?assertEqual(<<"Test will message">>, Msg),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 0, {F}}]), 
	?assertEqual({suback,[0]}, R1_0),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 0}, <<"Test Payload QoS = 0. annon. function callback. ">>)
	catch
		_:_ -> ok
	end,

  wait_all(1),

	unregister(test_result),
	?PASSED
end};

%% .
will_0({1, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=1.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(1, Q),
					 ?assertEqual("AK_will_test", Topic),
					 ?assertEqual(<<"Test will message">>, Msg),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 1, {F}}]), 
	?assertEqual({suback,[1]}, R1_0),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 1}, <<"Test Payload QoS = 1. annon. function callback. ">>)	
	catch
		_:_ -> ok
	end,

  wait_all(1),

	unregister(test_result),
	?PASSED
end};

%% .
will_0({2, will} = _X, [Publisher, Subscriber] = _Conns) -> {"will QoS=2.", timeout, 100, fun() ->
	register(test_result, self()),
  
	F = fun({{Topic, Q}, _QoS, Msg} = _Arg) -> 
%					 ?debug_Fmt("::test:: fun callback: ~100p",[_Arg]),
					 ?assertEqual(2, Q),
					 ?assertEqual("AK_will_test", Topic),
					 ?assertEqual(<<"Test will message">>, Msg),
					 test_result ! done 
			end,
	R1_0 = mqtt_client:subscribe(Subscriber, [{"AK_will_test", 2, {F}}]), 
	?assertEqual({suback,[2]}, R1_0),
%% generate connection lost:
	gen_server:call(Publisher, {set_test_flag, break_connection}),
	try
		mqtt_client:publish(Publisher, #publish{topic = "AKtest", qos = 2}, <<"Test Payload QoS = 2. annon. function callback. ">>)
	catch
		_:_ -> ok
	end,

  wait_all(1),

	unregister(test_result),
	?PASSED
end}.
