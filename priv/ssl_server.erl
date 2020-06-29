%% @author alexei
%% @doc @todo Add description to ssl_server.


-module(ssl_server).

-include_lib("eunit/include/eunit.hrl").
-include("test.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, client/1, accept/1]).

ssl_test_() -> [fun start/0].

start() ->
	ssl:start(),
	server(9999),
	timer:sleep(100),
	Resp = client("Hi"),
	?debug_Fmt("::test:: Client receives : ~p~n", [Resp]),
	timer:sleep(100).

server(Port) ->
	{ok, LSocket} = ssl:listen(Port, 
%% 														 [{certfile,"test/tsl/certificate.pem"}, 
%% 															{keyfile, "test/tsl/key.pem"}, 
														 [{cacertfile, "test/tsl/ca.crt"},
															{certfile,"test/tsl/server.crt"}, 
															{keyfile, "test/tsl/server.key"},
															{verify, verify_peer}, 
															{reuseaddr, true}, 
															{active, false}]
														),
	spawn(fun() -> accept(LSocket) end).

accept(LSocket) ->
	case ssl:transport_accept(LSocket) of
		{ok, Socket} -> 
			ok = ssl:ssl_accept(Socket),
			Pid = spawn(
							fun() ->
								io:format(user, "Connection accepted ~p~n", [Socket]),
								loop(Socket)
							end
						 		),
			ssl:controlling_process(Socket, Pid),
			accept(LSocket);
		_ -> ok
		end.

loop(Socket) ->
	ssl:setopts(Socket, [{active, once}]),
	receive
		{ssl,Sock, Data} ->
			io:format(user, "Got packet: ~p~n", [Data]),
			ssl:send(Sock, Data),
			loop(Socket);
		{ssl_closed, Sock} ->
			io:format(user, "Closing socket: ~p~n", [Sock]);
		Error ->
			io:format(user, "Error on socket: ~p~n", [Error])
	end.

client(N) ->
	{ok, Socket} = ssl:connect("Alexei-Mac.attlocal.net", 
															9999, 
															[{cacertfile, "test/tsl/ca.crt"},
																{certfile,"test/tsl/client.crt"}, 
																{keyfile, "test/tsl/client.key"},
																{verify, verify_none} 
															]
														),
	io:format(user, "Client opened socket: ~p~n",[Socket]),
	ok = ssl:send(Socket, N),
	Value = 
		receive
			{ssl,Socket, Data} ->
				io:format(user, "Client received: ~p~n",[Data]),
				Data
			after 2000 ->
				0
		end,
	ssl:close(Socket),
	Value.
%% ====================================================================
%% Internal functions
%% ====================================================================


