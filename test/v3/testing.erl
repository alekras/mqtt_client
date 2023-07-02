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

%% @since 2015-12-25
%% @copyright 2015-2023 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to testing.


-module(testing).
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

%%
%% API functions
%%
-export([
	do_setup/1, 
	do_cleanup/2, 
	do_start/0, 
	do_stop/1,
	get_connect_rec/1, 
	wait_all/1
]).

do_start() ->
	?debug_Fmt("~n=============~n Start test on server: ~p:~p, connection type:~p~n=============~n",
						 [?TEST_SERVER_HOST_NAME, ?TEST_SERVER_PORT, ?TEST_CONN_TYPE]),
	callback:start(),
	?assertEqual(ok, application:start(mqtt_client)).

do_stop(_R) ->
	callback:stop(),
	?assertEqual(ok, application:stop(mqtt_client)).

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
		{callback, call},
		[]
	),
%	?debug_Fmt("~n::test:: connect: ~p",[Pid]),
	Pid.

do_setup({Client_Id, connect} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[create(Client_Id)];
do_setup({_, publish} = _X) ->
	[connect(publisher), connect(subscriber)];
do_setup({_, session}) ->
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{clean_session = 0}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P1)),
	S1 = create(subscriber),
	ok = mqtt_client:connect(
		S1, 
		?CONN_REC(subscriber)#connect{clean_session = 1}, 
		{callback, call},
		[]
	),
	?assert(is_pid(S1)),
	[P1, S1];
do_setup({QoS, will}) ->
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
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{
			will_publish= #publish{qos= QoS, retain= 1, topic= "AK_will_retain_test", payload= <<"Test will retain message">>}
		}, 
		[]
	),
	?assert(is_pid(P)),
	ok = mqtt_client:publish(P, #publish{topic = "AK_will_retain_test", retain = 1, qos = QoS}, <<>>), %% in case if previous clean up failed
	[P, connect(subscriber)];
do_setup({_QoS, retain} = _X) ->
	[connect(publisher), connect(subscriber01), connect(subscriber02)];
do_setup({_, keep_alive}) ->
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC(publisher)#connect{keep_alive = 5},
		{callback, call}, 
		[]
	),
	?assert(is_pid(P)),
	P;
do_setup(_X) ->
	connect(publisher).

do_cleanup({testClient0, connect}, [_P]) ->
	callback:reset();
do_cleanup({_, connect}, [P]) ->
	callback:reset(),
	ok = mqtt_client:dispose(P);
do_cleanup({_, publish}, [P, S]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({_, session}, [P1, S1]) ->
	ok = mqtt_client:dispose(P1),
	ok = mqtt_client:dispose(S1),
	(get_storage()):cleanup(client);
do_cleanup({_QoS, will}, [P, S]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({QoS, will_retain}, [P, S]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),

	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC(publisher)#connect{
			clean_session = 1
		}, 
		[]
	),
	ok = mqtt_client:publish(P1, #publish{topic = "AK_will_retain_test", retain = 1, qos = QoS}, <<>>), 
	ok = mqtt_client:dispose(P1),

	(get_storage()):cleanup(client);
do_cleanup({QoS, retain}, [P1, S1, S2]) ->
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),
	ok = case mqtt_client:status(P1) of
		disconnected ->
			P2 = create(publisher),
			ok = mqtt_client:connect(
				P2, 
				?CONN_REC(publisher)#connect{clean_session = 0},
				[]
			),
			ok = mqtt_client:publish(P2, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P2);
		[{connected, 1}, _, _] ->
			ok = mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P1);
		_ ->
			ok = mqtt_client:connect(
				P1, 
				?CONN_REC(publisher)#connect{clean_session = 0},
				[]
			),
			mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			mqtt_client:dispose(P1)
	end,
	(get_storage()):cleanup(client);
do_cleanup(_X, _Pids) ->
	callback:reset(),
	ok = mqtt_client:dispose(publisher),
	(get_storage()):cleanup(client).

get_connect_rec(Cl_Id) ->
	?CONN_REC(Cl_Id).

get_storage() ->
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_storage;
		dets -> mqtt_dets_storage
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
	after 1500 -> {fail, M}
	end.
