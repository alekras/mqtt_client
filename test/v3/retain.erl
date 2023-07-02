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
%% @doc This module implements a tesing of MQTT retain messages.

-module(retain).

%%
%% Include files
%%
%% -include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-export([
  retain_0/2,
  retain_1/2
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
%%					?assertEqual(QoS_expected, Q),
					?assertEqual(undefined, Q),
					?assertEqual(Topic_expected, Topic),
					?assertEqual(<<Msg_expected/binary, (list_to_binary((integer_to_list(QoS_expected))))/binary>>, Msg),
					test_result ! done 
				end).

retain_0({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(QoS, "AK_retain_test", <<"Test 0 retain message QoS=">>),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), %% in case if previous clean up failed
	?assert(wait_all(if QoS == 0 -> 0; ?ELSE -> 1 end)),

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", QoS}]), 
	?assert(wait_all(1)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1},
													 <<"Test 0 retain message QoS=", (list_to_binary((integer_to_list(QoS))))/binary>>),
	?assert(wait_all(if QoS == 0 -> 1; ?ELSE -> 2 end)),
	
	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", QoS}]), 
	?assert(wait_all(2)),

	unregister(test_result),
	?PASSED
end}.

%% .
retain_1({QoS, retain} = _X, [Publisher, Subscriber1, Subscriber2] = _Conns) -> {"retain QoS=" ++ integer_to_list(QoS) ++ ".", timeout, 100, fun() ->
	register(test_result, self()),
	set_handlers(QoS, "AK_retain_test", <<"Test 1 retain message QoS=">>),
	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), %% in case if previous clean up failed
	?assert(wait_all(if QoS == 0 -> 0; ?ELSE -> 1 end)),

	ok = mqtt_client:publish(Publisher, #publish{topic = "AK_retain_test", qos = QoS, retain = 1},
													 <<"Test 1 retain message QoS=", (list_to_binary((integer_to_list(QoS))))/binary>>),
	?assert(wait_all(if QoS == 0 -> 0; ?ELSE -> 1 end)),

	ok = mqtt_client:subscribe(Subscriber1, [{"AK_retain_test", QoS}]), 
	?assert(wait_all(2)),

	ok = mqtt_client:disconnect(Publisher),
	timer:sleep(100),

	ok = mqtt_client:subscribe(Subscriber2, [{"AK_retain_test", QoS}]), 
	?assert(wait_all(2)),

	unregister(test_result),
	?PASSED
end}.
