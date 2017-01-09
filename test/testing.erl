%%
%% Copyright (C) 2015-2017 by krasnop@bellsouth.net (Alexei Krasnopolski)
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

%% @since 2015-12-25
%% @copyright 2015-2017 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to testing.


-module(testing).
-include_lib("eunit/include/eunit.hrl").
-include("mqtt_client.hrl").
-include("test.hrl").

%%
%% API functions
%%
-export([
	do_setup/1, 
	do_cleanup/2, 
	do_start/0, 
	do_stop/1,
	get_connect_rec/0, 
	wait_all/1]).

do_start() ->
  R = application:start(mqtt_client),
	?assertEqual(ok, R).

do_stop(_R) ->
  R = application:stop(mqtt_client),
	?assertEqual(ok, R).

do_setup({_, publish} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	S = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	[P,S];
do_setup({_, session} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P1 = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest", password = <<"guest">>,
			clean_session = 0,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	S1 = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest", password = <<"guest">>,
			clean_session = 0,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	[P1, S1];
do_setup({QoS, will} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest", password = <<"guest">>,
			will = 1,
			will_qos = QoS,
			will_message = <<"Test will message">>,
			will_topic = "AK_will_test",
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	S = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest", password = <<"guest">>,
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	[P,S];
do_setup({QoS, will_retain} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest",
			password = <<"guest">>,
			will = 1,
			will_retain = 1,
			will_qos = QoS,
			will_message = <<"Test will retain message">>,
			will_topic = "AK_will_retain_test",
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
		S = mqtt_client:connect(
		subscriber, 
		#connect{
			client_id = "subscriber",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	),
	[P,S];
do_setup({_QoS, retain} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P1 = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest", password = <<"guest">>,
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	S1 = mqtt_client:connect(
		subscriber_1, 
		#connect{
			client_id = "subscriber_1",
			user_name = "guest", password = <<"guest">>,
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	S2 = mqtt_client:connect(
		subscriber_2, 
		#connect{
			client_id = "subscriber_2",
			user_name = "guest", password = <<"guest">>,
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
	[P1, S1, S2];
do_setup(_X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	mqtt_client:connect(
		test_cli, 
		#connect{
			client_id = "test_cli",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		?TEST_SERVER_PORT, 
		[]
	).

do_cleanup({_, publish} = _X, [P, S] = _Pids) ->
	R1 = mqtt_client:disconnect(P),
	R2 = mqtt_client:disconnect(S),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({_, session} = _X, [P1, S1] = _Pids) ->
	dets:delete_all_objects(session_db),
	R1 = mqtt_client:disconnect(P1),
	R2 = mqtt_client:disconnect(S1),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({QoS, will} = _X, [P, S] = _Pids) ->
	R1 = mqtt_client:disconnect(P),
	
	P1 = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest", password = <<"guest">>,
			will = 1,
			will_qos = QoS,
			will_message = <<"Test will message">>,
			will_topic = "AK_will_test",
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),

	R1_1 = mqtt_client:disconnect(P1),

	R2 = mqtt_client:disconnect(S),

	?assertEqual(ok, R1),
	?assertEqual(ok, R1_1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({QoS, will_retain} = _X, [P, S] = _Pids) ->
	R1 = mqtt_client:disconnect(P),
	R2 = mqtt_client:disconnect(S),

	P1 = mqtt_client:connect(
		publisher, 
		#connect{
			client_id = "publisher",
			user_name = "guest", password = <<"guest">>,
			will = 1,
			will_retain = 1,
			will_qos = QoS,
			will_message = <<"Test will retain message">>,
			will_topic = "AK_will_retain_test",
			clean_session = 1,
			keep_alive = 60000
		}, 
		"localhost", ?TEST_SERVER_PORT, 
		[]
	),
% 	R1_0 = mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = 0}, <<>>), 
%% 	mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = 0}, <<>>), 
%% 	mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = 0}, <<>>), 
%% 	mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = 0}, <<>>), 
%	?assertEqual(ok, R1_0),
%	R1_1 = mqtt_client:publish(P1, #publish{topic = "AK_will_test", retain = 1, qos = 0}, <<>>), 
%	?assertEqual(ok, R1_1),
	R3 = mqtt_client:disconnect(P1),

	?assertEqual(ok, R1),
	?assertEqual(ok, R2),
	?assertEqual(ok, R3);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({QoS, retain} = _X, [P1, S1, S2] = _Pids) ->
	Rs1 = mqtt_client:disconnect(S1),
	Rs2 = mqtt_client:disconnect(S2),
	R1 = case mqtt_client:status(P1) of
				disconnected ->
					P2 = mqtt_client:connect(
						publisher, 
						#connect{
							client_id = "publisher",
							user_name = "guest", password = <<"guest">>,
							clean_session = 0,
							keep_alive = 60000
						}, 
						"localhost", ?TEST_SERVER_PORT, 
						[]
					),
					mqtt_client:publish(P2, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
					mqtt_client:disconnect(P2);
				_ ->
					mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
					mqtt_client:disconnect(P1)
			 end,
	?assertEqual(ok, R1),
	?assertEqual(ok, Rs1),
	?assertEqual(ok, Rs2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup(_X, _Pids) ->
	R = mqtt_client:disconnect(test_cli),
	?assertEqual(ok, R).

get_connect_rec() ->
	#connect{
		client_id = "test_client",
		user_name = "guest",
		password = <<"guest">>,
		clean_session = 1,
		keep_alive = 1000
	}.

wait_all(N) ->
	case wait_all(N, 0) of
		{ok, _M} -> 
%			?debug_Fmt("::test:: all ~p done received.", [_M]),
			true;
		{fail, _T} -> 
			?debug_Fmt("::test:: ~p done have not received.", [N - _T]), 
			false
%			?assert(true)
	end
	and
	case wait_all(N, 0) of
		{fail, _Z} -> 
%			?debug_Fmt("::test:: ~p additional done received.", [_Z]),
			true;
		{ok, _R} -> 
			?debug_Fmt("::test:: ~p unexpected done received.", [_R]), 
			false
%			?assert(true)
	end.

wait_all(0, M) -> {ok, M};
wait_all(N, M) ->
	receive
		done -> wait_all(N - 1, M + 1)
	after 1000 -> {fail, M}
	end.
