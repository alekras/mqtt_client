%% @author alexei
%% @doc @todo Add description to mock_tcp.

-module(callback).

-include_lib("eunit/include/eunit.hrl").

-record(callback_handlers, {
	onConnect_handler :: function(),
	onSubscribe_handler :: function(),
	onUnsubscribe_handler :: function(),
	onReceive_handler :: function(),
	onPong_handler :: function(),
	onPublish_handler :: function(),
	onClose_handler :: function(),
	onError_handler :: function()
}).
-record(callback_state, {handlers = #{} :: map()}).
%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start/0,
	stop/0,
	reset/0,
	set_event_handler/2,
	set_event_handler/3,
	call/2,
	call_0/2,
	call_1/2,
	call_2/2,
	call_3/2,
	loop/1]).

start() ->
	Pid = spawn_link(?MODULE, loop, [#callback_state{}]),
	register(callback_srv, Pid),
	io:format(user, "~n >>> CALLBACK_SRV process is started. (PID: ~p, registered under callback_srv). Parent process:~p *****~n", [Pid, self()]),
	reset(),
	ok.

stop() -> 
	callback_srv ! stop,
	unregister(callback_srv).

reset() ->
	callback_srv ! reset.

set_event_handler(Event, Handler) when is_atom(Event) ->
	callback_srv ! {set_handler, 0, Event, Handler}.

set_event_handler(Idx, Event, Handler) when is_atom(Event) ->
	callback_srv ! {set_handler, Idx, Event, Handler}.

call(Event, Argument) ->
	callback_srv ! {call, 0, Event, Argument}.

call_0(Event, Argument) ->
	callback_srv ! {call, 0, Event, Argument}.

call_1(Event, Argument) ->
	callback_srv ! {call, 1, Event, Argument}.

call_2(Event, Argument) ->
	callback_srv ! {call, 2, Event, Argument}.

call_3(Event, Argument) ->
	callback_srv ! {call, 3, Event, Argument}.

%% ====================================================================
%% Internal functions
%% ====================================================================

%% Implementation of callback server
loop(State) ->
	receive
		stop -> ok;
		reset ->
			Default_callback = fun(Event, Arg) ->
				io:format(user, " *** Default callback handler: event=~p; arg=~100p~n", [Event, Arg])
			end,
			Default_handlers = #callback_handlers{
				onConnect_handler = Default_callback,
				onSubscribe_handler = Default_callback,
				onUnsubscribe_handler = Default_callback,
				onReceive_handler = Default_callback,
				onPong_handler = Default_callback,
				onPublish_handler = Default_callback,
				onClose_handler = Default_callback,
				onError_handler = Default_callback
			},

			loop(#callback_state{
				handlers = #{
					0 => Default_handlers,
					1 => Default_handlers,
					2 => Default_handlers,
					3 => Default_handlers
				}
			});
		{set_handler, Idx, Event, Handler} ->
			#{Idx := Handlers} = (State#callback_state.handlers),
			New_handlers = 
			case Event of
				onConnect ->     Handlers#callback_handlers{onConnect_handler = Handler};
				onSubscribe ->   Handlers#callback_handlers{onSubscribe_handler = Handler};
				onUnsubscribe -> Handlers#callback_handlers{onUnsubscribe_handler = Handler};
				onPublish ->     Handlers#callback_handlers{onPublish_handler = Handler};
				onReceive ->     Handlers#callback_handlers{onReceive_handler = Handler};
				onPong ->        Handlers#callback_handlers{onPong_handler = Handler};
				onClose ->       Handlers#callback_handlers{onClose_handler = Handler};
				onError ->       Handlers#callback_handlers{onError_handler = Handler};
				_ ->
					io:format(user, "~n ERROR: wrong Event to set handler of callback process: ~p~n", [Event]),
					State
			end,
			New_map = (State#callback_state.handlers)#{Idx := New_handlers},
			New_state = State#callback_state{handlers = New_map},
			loop(New_state);

		{call, Idx, Event, Argument} ->
			#{Idx := Handlers} = (State#callback_state.handlers),
			case Event of
				onConnect ->     (Handlers#callback_handlers.onConnect_handler)(Event, Argument);
				onSubscribe ->   (Handlers#callback_handlers.onSubscribe_handler)(Event, Argument);
				onUnsubscribe -> (Handlers#callback_handlers.onUnsubscribe_handler)(Event, Argument);
				onPublish ->     (Handlers#callback_handlers.onPublish_handler)(Event, Argument);
				onReceive ->     (Handlers#callback_handlers.onReceive_handler)(Event, Argument);
				onPong ->        (Handlers#callback_handlers.onPong_handler)(Event, Argument);
				onClose ->       (Handlers#callback_handlers.onClose_handler)(Event, Argument);
				onError ->       (Handlers#callback_handlers.onError_handler)(Event, Argument);
				_ ->
					io:format(user, "~n ERROR: wrong Event as argument of call fun of callback process: ~p~n", [Event])
			end,
			loop(State);

		Msg ->
			io:format(user, "~n ERROR: wrong message arrives to callback process: ~p~n", [Msg]),
			loop(State)
	end.
