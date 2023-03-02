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

%% @since 2015-12-25
%% @copyright 2015-2022 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to testing.


-module(testing).
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

-define(CONN_REC(X), (#connect{
		client_id = X,
		host = ?TEST_SERVER_HOST_NAME,
		port = ?TEST_SERVER_PORT,
		user_name = ?TEST_USER,
		password = ?TEST_PASSWORD,
		conn_type = ?TEST_CONN_TYPE,
		keep_alive = 60000,
		version = ?TEST_PROTOCOL})
).

%%
%% API functions
%%
-export([
	do_setup/1, 
	do_cleanup/2, 
	do_start/0, 
	do_stop/1,
	get_connect_rec/1, 
	wait_all/1]).

do_start() ->
	R = application:start(mqtt_client),
	?assertEqual(ok, R).

do_stop(_R) ->
	R = application:stop(mqtt_client),
	?assertEqual(ok, R).

create(Name) when is_atom(Name) -> mqtt_client:create(Name);
create(Name) when is_list(Name) -> mqtt_client:create(list_to_atom(Name)).

connect(Name) ->
	connect(Name, Name).

connect(Name, CID) ->
	Pid = create(Name),
	?assert(is_pid(Pid)),
	ok = mqtt_client:connect(
		Pid, 
		?CONN_REC(CID), 
		[]
	),
%	?debug_Fmt("~n::test:: connect: ~p",[Pid]),
	Pid.

do_setup({Client_Id, connect} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[create(Client_Id)];
do_setup({_, publish} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[connect(publisher), connect(subscriber)];
do_setup({_, session} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		[]
	),
	?assert(is_pid(P1)),
	S1 = create(subscriber),
	ok = mqtt_client:connect(
		S1, 
		?CONN_REC(subscriber)#connect{clean_session = 0}, 
		[]
	),
	?assert(is_pid(S1)),
	[P1, S1];
do_setup({QoS, will} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{qos= QoS, topic= "AK_will_test", payload= <<"Test will message">>}
		}, 
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({QoS, will_retain} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{qos= QoS, retain= 1, topic= "AK_will_retain_test", payload= <<"Test will retain message">>}
		}, 
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({_QoS, retain} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[connect(publisher), connect(subscriber01), connect(subscriber02)];
do_setup({_, keep_alive}) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{keep_alive = 5}, 
		[]
	),
	?assert(is_pid(P)),
	P;
do_setup(_X) ->
  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	connect(publisher).

do_cleanup({testClient0, connect} = _X, [_P] = _Pids) ->
	ok;
do_cleanup({_, connect} = _X, [P] = _Pids) ->
	R1 = mqtt_client:dispose(P),
	?assertEqual(ok, R1);
do_cleanup({_, publish} = _X, [P, S] = _Pids) ->
	R1 = mqtt_client:dispose(P),
	R2 = mqtt_client:dispose(S),
	(get_storage()):cleanup(client),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({_, session} = _X, [P1, S1] = _Pids) ->
	R1 = mqtt_client:dispose(P1),
	R2 = mqtt_client:dispose(S1),
	(get_storage()):cleanup(client),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({_QoS, will} = _X, [P, S] = _Pids) ->
	R1 = mqtt_client:dispose(P),
	R2 = mqtt_client:dispose(S),
	(get_storage()):cleanup(client),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup({QoS, will_retain} = _X, [P, S] = _Pids) ->
%	?debug_Fmt("::test:: do cleanup: ~p  pids=~p",[_X, _Pids]),
	R1 = mqtt_client:dispose(P),
	R2 = mqtt_client:dispose(S),

	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{
			clean_session = 1
		}, 
		[]
	),
	R1_0 = mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = QoS}, <<>>), 
	?assertEqual(ok, R1_0),
	R3 = mqtt_client:dispose(P1),

	(get_storage()):cleanup(client),
	?assertEqual(ok, R1),
	?assertEqual(ok, R2),
	?assertEqual(ok, R3);
%	?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2, R3}]);
do_cleanup({QoS, retain} = _X, [P1, S1, S2] = _Pids) ->
	Rs1 = mqtt_client:dispose(S1),
	Rs2 = mqtt_client:dispose(S2),
	R1 = case mqtt_client:status(P1) of
		disconnected ->
			P2 = create(publisher),
			ok = mqtt_client:connect(
				P2, 
				?CONN_REC(publisher)#connect{clean_session = 0},
				[]
			),
			mqtt_client:publish(P2, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			mqtt_client:dispose(P2);
		_ ->
			mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			mqtt_client:dispose(P1)
	end,
	(get_storage()):cleanup(client),
	?assertEqual(ok, R1),
	?assertEqual(ok, Rs1),
	?assertEqual(ok, Rs2);
%  ?debug_Fmt("::test:: teardown after: ~p  pids=~p  disconnect returns=~150p",[_X, _Pids, {R1, R2}]);
do_cleanup(_X, _Pids) ->
	R = mqtt_client:dispose(publisher),
	(get_storage()):cleanup(client),
	?assertEqual(ok, R).

get_connect_rec(Cl_Id) ->
	?CONN_REC(Cl_Id).

get_storage() ->
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_dao;
		dets -> mqtt_dets_dao
	end.
	
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
	case wait_all(100, 0) of
		{fail, 0} -> 
%			?debug_Fmt("::test:: ~p unexpected done received.", [0]),
			true;
		{fail, _Z} -> 
			?debug_Fmt("::test:: ~p unexpected done received.", [_Z]),
			false;
		{ok, _R} -> 
			?debug_Fmt("::test:: ~p unexpected done received.", [_R]), 
			false
%			?assert(true)
	end.

wait_all(0, M) -> {ok, M};
wait_all(N, M) ->
	receive
		done -> wait_all(N - 1, M + 1)
	after 500 -> {fail, M}
	end.
