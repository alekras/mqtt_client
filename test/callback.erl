%% @author alexei
%% @doc @todo Add description to mock_tcp.

-module(callback).

-include_lib("eunit/include/eunit.hrl").

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
			Default_handlers = #{
				onConnect     => Default_callback,
				onSubscribe   => Default_callback,
				onUnsubscribe => Default_callback,
				onReceive     => Default_callback,
				onPong        => Default_callback,
				onPublish     => Default_callback,
				onClose       => Default_callback,
				onError       => Default_callback
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
			New_handlers = Handlers#{Event := Handler},
			New_map = (State#callback_state.handlers)#{Idx := New_handlers},
			New_state = State#callback_state{handlers = New_map},
			loop(New_state);

		{call, Idx, Event, Argument} ->
			#{Idx := Handlers} = (State#callback_state.handlers),
			#{Event := Handler} = Handlers,
			(Handler)(Event, Argument),
			loop(State);

		Msg ->
			io:format(user, "~n ERROR: wrong message arrives to callback process: ~p~n", [Msg]),
			loop(State)
	end.
