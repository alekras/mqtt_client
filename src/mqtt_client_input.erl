%%
%% Copyright (C) 2015-2016 by krasnop@bellsouth.net (Alexei Krasnopolski)
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
%% @copyright 2015-2016 Alexei Krasnopolski
%% @author Alexei Krasnopolski <krasnop@bellsouth.net> [http://krasnopolski.org/]
%% @version {@version}
%% @doc @todo Add description to mqtt_client_input.


-module(mqtt_client_input).

%%
%% Include files
%%
-include("mqtt_client.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	input_parser/1
]).

-ifdef(TEST).
-export([
	decode_remaining_length/1
]).
-endif.

%% ====================================================================
%% Internal functions
%% ====================================================================

input_parser(Binary) ->
	case Binary of
		<<?CONNACK_PACK_TYPE, 2:8, 0:7, SP:1, Connect_Return_Code:8, Tail/binary>> -> {connectack, SP, return_code_response(Connect_Return_Code), Tail};
		<<?PUBLISH_PACK_TYPE, _DUP:1, QoS:2, _RETAIN:1, Bin/binary>> ->
			{RestBin, Length} = decode_remaining_length(Bin),
			<<L:16, TopicBin:L/binary, RestBin1/binary>> = RestBin,
			Topic = unicode:characters_to_list(TopicBin, utf8),
			case QoS of
				0 ->
					PL = Length - L - 2,
					<<Payload:PL/binary, Tail/binary>> = RestBin1,
%					io:format(user, " >>> PUBLISH (QoS = 0) received: Length=~p L=~p Topic=~p Payload=~p Tail=~p~n", [Length, L, Topic, Payload, Tail]),
					{publish, 0, 0, Topic, Payload, Tail};
				_ when (QoS =:= 1) orelse (QoS =:= 2) ->
					PL = Length - L - 4,
					<<Packet_Id:16, Payload:PL/binary, Tail/binary>> = RestBin1,
%					io:format(user, " >>> PUBLISH (QoS = ~p) received: Pk_Id=~p Length=~p L=~p Topic=~p Payload=~p Tail=~p~n", [QoS, Packet_Id, Length, L, Topic, Payload, Tail]),
					{publish, QoS, Packet_Id, Topic, Payload, Tail};
				_ -> true
			end;
		<<?PUBACK_PACK_TYPE, 2:8, Packet_Id:16, Tail/binary>> -> {puback, Packet_Id, Tail};
		<<?PUBREC_PACK_TYPE, 2:8, Packet_Id:16, Tail/binary>> -> {pubrec, Packet_Id, Tail};
		<<?PUBREL_PACK_TYPE, 2:8, Packet_Id:16, Tail/binary>> -> {pubrel, Packet_Id, Tail};
		<<?PUBCOMP_PACK_TYPE, 2:8, Packet_Id:16, Tail/binary>> -> {pubcomp, Packet_Id, Tail};
		<<?SUBACK_PACK_TYPE, Bin/binary>> -> 
			{RestBin, Length} = decode_remaining_length(Bin),
			L = Length - 2,
			<<Packet_Id:16, Return_codes:(L)/binary, Tail/binary>> = RestBin,
%			io:format(user, " >>> SUBACK received: ~p ~p ~p Len=~p~n", [Packet_Id, binary_to_list(Return_codes), Tail, Length]),
			{suback, Packet_Id, binary_to_list(Return_codes), Tail};
		<<?UNSUBACK_PACK_TYPE, Bin/binary>> -> 
			{RestBin, _Length} = decode_remaining_length(Bin),
			<<Packet_Id:16, Tail/binary>> = RestBin,
%			io:format(user, " >>> UNSUBACK received: ~p ~p Len=~p~n", [Packet_Id, Tail, _Length]),
			{unsuback, Packet_Id, Tail};
		<<?PINGRESP_PACK_TYPE, 0:8, Tail/binary>> -> {pingresp, Tail};
		_ -> 
			io:format(user, " >>> Unknown Binary received ~p~n", [Binary]),
%%			#mqtt_client_error{type = connection, source = "input_parser/1", message = "Unknown Control Packet Type"}
			{unparsed, Binary}
	end.

return_code_response(0) -> "0x00 Connection Accepted";
return_code_response(1) -> "0x01 Connection Refused, unacceptable protocol version";
return_code_response(2) -> "0x02 Connection Refused, identifier rejected";
return_code_response(3) -> "0x03 Connection Refused, Server unavailable";
return_code_response(4) -> "0x04 Connection Refused, bad user name or password";
return_code_response(5) -> "0x05 Connection Refused, not authorized";
return_code_response(_) -> "Return Code is not recognizable".

decode_remaining_length(Binary) ->
	decode_rl(Binary, 1, 0).

decode_rl(_, MP, L) when MP > (128 * 128 * 128) -> {error, L};
decode_rl(<<CB:1, EncodedByte:7, Binary/binary>>, MP, L) ->
	NewL = L + EncodedByte * MP,
	if 
		CB == 1 -> decode_rl(Binary, MP * 128, NewL);
		true -> {Binary, NewL}
	end.

