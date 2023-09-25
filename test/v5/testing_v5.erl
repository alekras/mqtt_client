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


-module(testing_v5).
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include_lib("mqtt_common/include/mqtt_property.hrl").
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
%	wait_all/1,
%	wait/4,
%	wait/5,
	wait_events/2
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
	connect(Name, Name, call).

connect(Name, Callback_fun) ->
	connect(Name, Name, Callback_fun).

connect(Name, CID, Callback_fun) ->
	Pid = create(Name),
	?assert(is_pid(Pid)),
	ok = mqtt_client:connect(
		Pid, 
		?CONN_REC_5(CID)#connect{properties=[{?Topic_Alias_Maximum,10}]}, 
		{callback, Callback_fun},
		[]
	),
%	?debug_Fmt("~n::test:: connect: ~p",[Pid]),
	Pid.

do_setup({Client_Id, connect} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	callback:reset(),
	[create(Client_Id)];
do_setup({_, publish}) ->
	[connect(publisher), connect(subscriber)];
do_setup({_, publish_rec_max} = _X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC_5(publisher)#connect{properties=[{?Receive_Maximum, 5}]}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P1)),
	[P1, connect(subscriber)];
do_setup({_, share}) ->
	[
		connect(publisher),
		connect(subscriber1),
		connect(subscriber2, call_1),
		connect(subscriber3, call_2),
		connect(subscriber4, call_3)
	];
do_setup({_, session}) ->
	callback:reset(),
	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC_5(publisher)#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P1)),
	S1 = create(subscriber),
	ok = mqtt_client:connect(
		S1, 
		?CONN_REC_5(subscriber)#connect{clean_session = 0, properties=[{?Session_Expiry_Interval, 16#FFFFFFFF}]}, 
		{callback, call},
		[]
	),
	?assert(is_pid(S1)),
	[P1, S1];
do_setup({_, session_expire}) ->
	[create(subscriber)];
do_setup({QoS, will}) ->
	P = create(publisher),
	Payload = "Test will retain message QoS: " ++ integer_to_list(QoS),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC_5(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				topic= "AK_will_test",
				payload= list_to_binary(Payload)
			}
		}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({QoS, will_delay}) ->
	P = create(publisher),
	Payload = "Test will retain message QoS: " ++ integer_to_list(QoS),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC_5(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				topic= "AK_will_test",
				payload= list_to_binary(Payload),
				properties =[{?Will_Delay_Interval, 5}]}
		}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P)),
	[P, connect(subscriber)];
do_setup({QoS, will_retain}) ->
	P = create(publisher),
	Payload = "Test will retain message QoS: " ++ integer_to_list(QoS),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC_5(publisher)#connect{
			will_publish= #publish{
				qos= QoS,
				retain= 1,
				topic= "AK_will_retain_test",
				payload= list_to_binary(Payload)
			}
		}, 
		{callback, call},
		[]
	),
	ok = mqtt_client:publish(P, #publish{topic = "AK_will_retain_test", retain = 1, qos = 0}, <<>>), 
	?assert(is_pid(P)),
	[P, connect(subscriber), create(subscriber2)];
do_setup({_QoS, retain}) ->
	callback:reset(),
	P1 = connect(publisher),
	ok = mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = 0}, <<>>), 
	[P1, connect(subscriber1), connect(subscriber2, call_1)];
do_setup({_, keep_alive}) ->
	callback:reset(),
	P = create(publisher),
	ok = mqtt_client:connect(
		P, 
		?CONN_REC_5(publisher)#connect{keep_alive = 5}, 
		{callback, call},
		[]
	),
	?assert(is_pid(P)),
	P;
do_setup(_X) ->
%  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	connect(publisher).

do_cleanup({testClient0, connect}, [_P]) ->
	ok;
do_cleanup({_, connect}, [P]) ->
	ok = mqtt_client:dispose(P);
do_cleanup({_, Tag} = _X, [P, S] = _Pids) when Tag == publish; Tag == publish_rec_max ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({_, share}, [P, S1, S2, S3, S4]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),
	ok = mqtt_client:dispose(S3),
	ok = mqtt_client:dispose(S4),
	(get_storage()):cleanup(client);
do_cleanup({_, session}, [P1, S1]) ->
	ok = mqtt_client:dispose(P1),
	ok = mqtt_client:dispose(S1),
	(get_storage()):cleanup(client);
do_cleanup({_, session_expire}, [S]) ->
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({_QoS, Tag}, [P, S]) when Tag == will; Tag == will_delay ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S),
	(get_storage()):cleanup(client);
do_cleanup({QoS, will_retain}, [P, S1, S2]) ->
	ok = mqtt_client:dispose(P),
	ok = mqtt_client:dispose(S1),
	ok = mqtt_client:dispose(S2),

	P1 = create(publisher),
	ok = mqtt_client:connect(
		P1, 
		?CONN_REC_5(publisher)#connect{
			clean_session = 1
		}, 
		{callback, call},
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
				?CONN_REC_5(publisher)#connect{clean_session = 0}, 
				{callback, call},
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
				?CONN_REC_5(publisher)#connect{clean_session = 0},
				{callback, call},
				[]
			),
			ok = mqtt_client:publish(P1, #publish{topic = "AK_retain_test", retain = 1, qos = QoS}, <<>>), 
			ok = mqtt_client:dispose(P1)
	end,
	(get_storage()):cleanup(client);
do_cleanup(_X, _Pids) ->
	ok = mqtt_client:dispose(publisher),
	(get_storage()):cleanup(client).

get_connect_rec(Cl_Id) ->
	?CONN_REC_5(Cl_Id).

get_storage() ->
	case application:get_env(mqtt_client, storage, dets) of
		mysql -> mqtt_mysql_storage;
		dets -> mqtt_dets_storage
	end.

wait_events(Title, Events_list) ->
	wait_events(Title, Events_list, true).

wait_events(Title, Events_list, Result) ->
	case wait(Events_list) of
		ok ->
			case Result of
				true ->
					?debug_Fmt("::wait_events::=>'~s' all events come ~p.~n", [Title, Events_list]);
				false ->
					?debug_Fmt("::wait_events::=>'~s' all expected events come ~p but enexpected events exist.~n", [Title, Events_list])
			end,
			Result and true;
		{fail, none, New_events_list} ->
			?debug_Fmt("::wait_events::=>'~s' ~p some events have not received.~n", [Title, New_events_list]),
			Result and false;
		{fail, Event, New_events_list} ->
			?debug_Fmt("::wait_events::=>'~s' ~p unexpected event '~p' received.~n", [Title, New_events_list, Event]),
			wait_events(Title, New_events_list, false)
	end.

wait([]) -> 
	receive 
		Event ->
			{fail, Event, []}
	after ?MQTT_GEN_SERVER_TIMEOUT + 100 ->
			ok
	end;
wait(Events_list) ->
	receive
		Event ->
			case lists:member(Event, Events_list) of
				true ->
					wait(lists:delete(Event, Events_list));
				false ->
					{fail, Event, Events_list}
			end
	after ?MQTT_GEN_SERVER_TIMEOUT + 100 ->
			{fail, none, Events_list}
	end.
