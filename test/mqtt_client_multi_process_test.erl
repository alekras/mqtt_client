%% @author alexei
%% @doc @todo Add description to mqtt_server_multi_clients.


-module(mqtt_client_multi_process_test).
-include_lib("eunit/include/eunit.hrl").
-include_lib("mqtt_common/include/mqtt.hrl").
-include("test.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start_task/2,
	publisher_process/4,
	subscriber_process/4
]).

mqtt_multi_process_test_() ->
	[ 
		{ setup, 
			fun do_start/0, 
			fun do_stop/1, 
				{ foreachx, 
					fun do_setup/1, 
					fun do_cleanup/2, 
					[
						{{1, start_test}, fun start_task/2}
					]}
		}
	].

start_task(_, []) -> {"start task", timeout, 150, fun() ->
	N_Pub = 1000,
	Sub_Topics = [{"Spring/Apr/+", 1},{"Winter/#", 2}, {"Summer/+/15", 0},{"Fall/Nov/15", 2}],
	Sub_N = 10 * N_Pub,
	Pub_List = [
		{[{"Winter/Jan/15", 1}, {"Summer/Jun/15", 1}], N_Pub},
		{[{"Summer/Jun/15", 1}, {"Fall/Nov/15", 2}],   N_Pub},
		{[{"Winter/Feb/15", 1}, {"Spring/Apr/30", 1}], N_Pub},
		{[{"Fall/Nov/15", 2}, {"Winter/Jan/15", 1}],   N_Pub},
		{[{"Spring/Apr/15", 1}, {"Fall/Nov/15", 2}],   N_Pub}
	],
	Conn_1 = testing:get_connect_rec(),
	Sub_Pid = mqtt_client:connect(
		subscriber, 
		Conn_1#connect{client_id = "subscriber", version = '5.0'}, 
		?TEST_SERVER_HOST_NAME, 
		?TEST_SERVER_PORT, 
		[?TEST_CONN_TYPE]),
	start_subscriber_process(Sub_Pid, Sub_Topics, Sub_N, self()),

	timer:sleep(1000),

	Conn_2 = testing:get_connect_rec(),
	Pub_Pid = mqtt_client:connect(
		publisher,
		Conn_2#connect{client_id = "publisher", version = '5.0'},
		?TEST_SERVER_HOST_NAME,
		?TEST_SERVER_PORT,
		[?TEST_CONN_TYPE]),
	[start_publisher_process(Pub_Pid, Topics, N, self()) || {Topics, N} <- Pub_List],
	counter(6),
	?PASSED
end}.

counter(0) -> ok;
counter(M) ->
	receive
		stop -> 
			?assert(true),
			counter(M - 1);
		error -> 
			?assert(false), 
			counter(M - 1)
	after 60000 -> 
			?assert(false)
	end.
%% ====================================================================
%% Internal functions
%% ====================================================================

do_start() ->
	C = application:start(mqtt_client),
	?assertEqual(ok, C).

do_stop(_R) ->
	C = application:stop(mqtt_client),
	?assertEqual(ok, C).

do_setup({_, start_test} = _X) ->
  ?debug_Fmt("~n::test:: setup before: ~p",[_X]),
	[].

do_cleanup({_, _} = _X, []) ->
  ?debug_Fmt("~n::test:: clean up after: ~p",[_X]).

start_publisher_process(Pub_Pid, Topics, N, Parent_Pid) ->
	spawn_link(?MODULE, publisher_process, [Pub_Pid, Topics, Parent_Pid, N]).

publisher_process(_Pid, _Topics, Parent_Pid, 0) ->
	?debug_Fmt("::test:: publisher send all messages for Topics = ~p.",[_Topics]),
%	mqtt_client:disconnect(Pid),
	Parent_Pid ! stop;
publisher_process(Pid, Topics, Parent_Pid, N) ->
	[ok = mqtt_client:publish(Pid, #publish{topic = Topic, qos = QoS}, gen_payload(N, "publisher:" ++ Topic)) || {Topic, QoS} <- Topics],
	timer:sleep(10), %% need for Mosquitto
	publisher_process(Pid, Topics, Parent_Pid, N-1).

gen_payload(N, Name) ->
	term_to_binary([{name, Name}, {number, N}, {message, "Test message."}]).

start_subscriber_process(Sub_Pid, Topics, N, Parent_Pid) ->
	Pid = erlang:spawn_link(?MODULE, subscriber_process, [Sub_Pid, Topics, Parent_Pid, N + 1]),

	CallBack = fun(A) -> process_message(A, Pid) end,
	T2 = [{T, Q, CallBack} || {T, Q} <- Topics],
	mqtt_client:subscribe(Sub_Pid, T2, []).

subscriber_process(Pid, Topics, Parent_Pid, 0) ->
	?debug_Fmt("::test:: subscriber receive +1 message.",[]),
	mqtt_client:unsubscribe(Pid, [T || {T, _} <- Topics]),
	mqtt_client:disconnect(Pid),
	Parent_Pid ! error;
subscriber_process(Pid, Topics, Parent_Pid, 1) ->
	?debug_Fmt("::test:: subscriber receive last message.",[]),
	mqtt_client:unsubscribe(Pid, [T || {T, _} <- Topics]),
	mqtt_client:disconnect(Pid),
	Parent_Pid ! stop;
subscriber_process(Pid, Topics, Parent_Pid, N) ->
	receive
		{Pub_Name, Mess_Number, Message} -> 
%			?debug_Fmt("::test:: subscriber processed message[~p]: ~128p",[N, {Pub_Name, Mess_Number, Message}]),
			subscriber_process(Pid, Topics, Parent_Pid, N - 1)
	after 10000 -> 
			?debug_Fmt("::test:: subscriber catched timeout while waiting message[~p]",[N]),
			mqtt_client:unsubscribe(Pid, [T || {T, _} <- Topics]),
			mqtt_client:disconnect(Pid),
			Parent_Pid ! error
	end.	

process_message({_Q, #publish{payload = Msg}} = _A, Dest_Pid) -> 
%  ?debug_Fmt("~n::test:: process message: ~128p",[A]),
	Payload = binary_to_term(Msg),
	Name = proplists:get_value(name, Payload),
	N = proplists:get_value(number, Payload),
	M = proplists:get_value(message, Payload),
	Dest_Pid ! {Name, N, M}.
