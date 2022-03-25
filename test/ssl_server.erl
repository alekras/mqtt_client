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
														 [{cacertfile, "test/certs/etc/server/cacerts.pem"},
															{certfile, "test/certs/etc/server/cert.pem"}, 
															{keyfile, "test/certs/etc/server/key.pem"},
%%															{verify, verify_peer}, 
															{verify, verify_none}, 
															{depth, 2},
															{server_name_indication, disable}, 
															{active, false}]
														),
	{ok, {LAddr, LPort}} = ssl:sockname(LSocket),
	io:format(user, "Listen: address= ~p; port= ~p.~n", [LAddr, LPort]),
	spawn(fun() -> accept(LSocket) end).

accept(LSocket) ->
	case ssl:transport_accept(LSocket) of
		{ok, ASocket} -> 
			case ssl:handshake(ASocket) of
				{ok, SslSocket} ->
					io:format(user, "Accept: accepted= ~p.~n", [SslSocket]),
					check_cert("Server(accept)", SslSocket),
					Pid = spawn(
							fun() ->
								io:format(user, "Connection accepted ~p~n", [SslSocket]),
								loop(SslSocket)
							end
					),
					ssl:controlling_process(SslSocket, Pid),
					accept(LSocket);
				{ok, _SslSocket, Ext} ->
					io:format(user, "Accept.Handshake: Ext= ~p.~n", [Ext]);
				{error, HSReason} ->
					io:format(user, "Accept.Handshake: error= ~p.~n", [HSReason])
			end;
		{error, Reason} -> 
			io:format(user, "Accept: error= ~p.~n", [Reason])
		end.

loop(Socket) ->
	ssl:setopts(Socket, [{active, once}]),
	receive
		{ssl,Sock, Data} ->
			io:format(user, "Server got packet: ~p~n", [Data]),
			ssl:send(Sock, Data ++ " from server."),
			loop(Socket);
		{ssl_closed, Sock} ->
			io:format(user, "Closing socket: ~p~n", [Sock]);
		Error ->
			io:format(user, "Error on socket: ~p~n", [Error])
	end.

client(Msg) ->
	{ok, Host} = inet:gethostname(), 
	{ok, Socket} = ssl:connect(Host, 
															9999, 
															[
%%																{cacertfile, "test/certs/etc/client/cacerts.pem"},
%%																{certfile, "test/certs/etc/client/cert.pem"}, 
%%																{keyfile, "test/certs/etc/client/key.pem"},
%%																{verify, verify_peer},
																{verify, verify_none},
																{depth, 2},
																{server_name_indication, disable}
															]
														),
	io:format(user, "Client opened socket: ~p~n",[Socket]),
	check_cert("Client", Socket),
	ok = ssl:send(Socket, Msg),
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

check_cert(Side, SslSocket) ->
	case ssl:peercert(SslSocket) of
		{ok, Cert} ->
			io:format(user, "~p: peer cert:~n~p~n", 
								[Side, public_key:pkix_decode_cert(Cert, otp)]);
		{error, Reason} ->
			io:format(user, "~p: No peer cert with error:~n~p~n", 
								[Side, Reason])
	end.
