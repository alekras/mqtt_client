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
%% @doc @todo Add description to mqtt_client_output.


-module(mqtt_client_output).

%%
%% Include files
%%
-include("mqtt_client.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	packet/2
]).

-ifdef(TEST).
-export([
	encode_remaining_length/1,
	fixed_header/3,
	variable_header/2,
	payload/2
]).
-endif.

packet(connect, Conn_config) ->
	Remaining_packet = <<(variable_header(connect, Conn_config))/binary, (payload(connect, Conn_config))/binary>>,
	<<(fixed_header(connect, 0, byte_size(Remaining_packet)))/binary, Remaining_packet/binary>>;
packet(connack, {SP, Connect_Return_Code}) -> <<(fixed_header(connack, 0, 2))/binary, 0:7, SP:1, Connect_Return_Code:8>>;
packet(publish, #publish{payload = Payload} = Params) ->
	Remaining_packet = <<(variable_header(publish, {Params#publish.topic}))/binary, 
											 (payload(publish, Payload))/binary>>,
	<<(fixed_header(publish, 
								 {Params#publish.dup, Params#publish.qos, Params#publish.retain}, 
								 byte_size(Remaining_packet)))/binary, 
								 Remaining_packet/binary>>;
packet(publish, {#publish{payload = Payload} = Params, Packet_Id}) ->
	Remaining_packet = <<(variable_header(publish, {Params#publish.topic, Packet_Id}))/binary, 
												(payload(publish, Payload))/binary>>,
	<<(fixed_header(publish, 
									{Params#publish.dup, Params#publish.qos, Params#publish.retain}, 
									byte_size(Remaining_packet)))/binary, 
									Remaining_packet/binary>>;
packet(subscribe, {Subscriptions, Packet_Id}) ->
	Remaining_packet = <<(variable_header(subscribe, Packet_Id))/binary, (payload(subscribe, Subscriptions))/binary>>,
	<<(fixed_header(subscribe, 0, byte_size(Remaining_packet)))/binary, Remaining_packet/binary>>;
packet(suback, {Return_Codes, Packet_Id}) ->
	Remaining_packet = <<(variable_header(suback, Packet_Id))/binary, (payload(suback, Return_Codes))/binary>>,
	<<(fixed_header(suback, 0, byte_size(Remaining_packet)))/binary, Remaining_packet/binary>>;
packet(unsubscribe, {Topics, Packet_Id}) ->
	Remaining_packet = <<(variable_header(unsubscribe, Packet_Id))/binary, (payload(unsubscribe, Topics))/binary>>,
	<<(fixed_header(unsubscribe, 0, byte_size(Remaining_packet)))/binary, Remaining_packet/binary>>;
packet(unsuback, Packet_Id) ->
	<<(fixed_header(unsuback, 0, 2))/binary, Packet_Id:16>>;
packet(disconnect, _) ->
	<<(fixed_header(disconnect, 0, 0))/binary>>;
packet(pingreq, _) ->
	<<(fixed_header(pingreq, 0, 0))/binary>>;
packet(pingresp, _) ->
	<<(fixed_header(pingresp, 0, 0))/binary>>;
packet(puback, Packet_Id) ->
	<<(fixed_header(puback, 0, 2))/binary, Packet_Id:16>>;
packet(pubrec, Packet_Id) ->
	<<(fixed_header(pubrec, 0, 2))/binary, Packet_Id:16>>;
packet(pubrel, Packet_Id) ->
	<<(fixed_header(pubrel, 0, 2))/binary, Packet_Id:16>>;
packet(pubcomp, Packet_Id) ->
<<(fixed_header(pubcomp, 0, 2))/binary, Packet_Id:16>>.

fixed_header(connect, _Flags, Length) ->
	<<?CONNECT_PACK_TYPE, (encode_remaining_length(Length))/binary>>;
fixed_header(connack, _Flags, _Length) ->
	<<?CONNACK_PACK_TYPE, 2:8>>;
fixed_header(publish, {Dup, QoS, Retain}, Length) ->
	<<?PUBLISH_PACK_TYPE, Dup:1, QoS:2, Retain:1, (encode_remaining_length(Length))/binary>>;
fixed_header(subscribe, _Flags, Length) ->
	<<?SUBSCRIBE_PACK_TYPE, (encode_remaining_length(Length))/binary>>;
fixed_header(suback, _Flags, Length) ->
	<<?SUBACK_PACK_TYPE, (encode_remaining_length(Length))/binary>>;
fixed_header(unsubscribe, _Flags, Length) ->
	<<?UNSUBSCRIBE_PACK_TYPE, (encode_remaining_length(Length))/binary>>;
fixed_header(unsuback, _Flags, _Length) ->
	<<?UNSUBACK_PACK_TYPE, 2:8>>;
fixed_header(puback, _Flags, _Length) ->
	<<?PUBACK_PACK_TYPE, 2:8>>;
fixed_header(pubrec, _Flags, _Length) ->
	<<?PUBREC_PACK_TYPE, 2:8>>;
fixed_header(pubrel, _Flags, _Length) ->
	<<?PUBREL_PACK_TYPE, 2:8>>;
fixed_header(pubcomp, _Flags, _Length) ->
	<<?PUBCOMP_PACK_TYPE, 2:8>>;
fixed_header(pingreq, _Flags, _Length) ->
	<<?PING_PACK_TYPE, 0:8>>;
fixed_header(pingresp, _Flags, _Length) ->
	<<?PINGRESP_PACK_TYPE, 0:8>>;
fixed_header(disconnect, _Flags, _Length) ->
	<<?DISCONNECT_PACK_TYPE, 0:8>>.

variable_header(connect, Config) ->
	User = if length(Config#connect.user_name) == 0 -> 0; true -> 1 end,
	Password = if length(Config#connect.password) == 0 -> 0; true -> 1 end,
	if (length(Config#connect.will_topic) == 0) or (byte_size(Config#connect.will_message) == 0) ->
				Will_retain = 0,
				Will_QoS = 0,
				Will = 0;
			true ->
				Will_retain = Config#connect.will_retain,
				Will_QoS = Config#connect.will_qos,
				Will = Config#connect.will
	end,
	Clean_Session = Config#connect.clean_session,
	Keep_alive = Config#connect.keep_alive,
	<<4:16, "MQTT", 4:8, User:1, Password:1, Will_retain:1, Will_QoS:2, Will:1, Clean_Session:1, 0:1, Keep_alive:16>>;
variable_header(publish, {Topic}) ->
	TopicBin = unicode:characters_to_binary(Topic, utf8),
	<<(byte_size(TopicBin)):16, TopicBin/binary>>;
variable_header(publish, {Topic, Packet_Id}) ->
	TopicBin = unicode:characters_to_binary(Topic, utf8),
	<<(byte_size(TopicBin)):16, TopicBin/binary, Packet_Id:16>>;
variable_header(subscribe, Packet_Id) ->
	<<Packet_Id:16>>;
variable_header(suback, Packet_Id) ->
	<<Packet_Id:16>>;
variable_header(unsubscribe, Packet_Id) ->
	<<Packet_Id:16>>.

payload(connect, Config) ->
	Client_id_bin = unicode:characters_to_binary(Config#connect.client_id, utf8),
	Will_bin =
	if Config#connect.will == 0 ->
				<<>>;
			true ->
				WT = unicode:characters_to_binary(Config#connect.will_topic, utf8),
				WM = Config#connect.will_message,
				<<(byte_size(WT)):16, WT/binary, (byte_size(WM)):16, WM/binary>>
	end,
	Username_bin =
	if length(Config#connect.user_name) == 0 ->
				<<>>;
			true ->
				UN = unicode:characters_to_binary(Config#connect.user_name, utf8),
				<<(byte_size(UN)):16, UN/binary>>
	end,
	Password_bin =
	if length(Config#connect.password) == 0 ->
				<<>>;
			true ->
				PW = Config#connect.password,
				<<(byte_size(PW)):16, PW/binary>>
	end,
	<<(byte_size(Client_id_bin)):16, Client_id_bin/binary, 
		Will_bin/binary, 
		Username_bin/binary,
		Password_bin/binary>>;
payload(publish, Payload) ->
	Payload;

payload(subscribe, []) -> <<>>;
payload(subscribe, [{Topic, QoS, _} | Subscriptions]) ->
	TopicBin = unicode:characters_to_binary(Topic, utf8),
	<<(byte_size(TopicBin)):16, TopicBin/binary, QoS:8, (payload(subscribe, Subscriptions))/binary>>;

payload(suback, []) -> <<>>;
payload(suback, [Return_Code | Return_Codes]) ->
	<<Return_Code:8, (payload(suback, Return_Codes))/binary>>;

payload(unsubscribe, []) -> <<>>;
payload(unsubscribe, [Topic | Topics]) ->
	TopicBin = unicode:characters_to_binary(Topic, utf8),
	<<(byte_size(TopicBin)):16, TopicBin/binary, (payload(unsubscribe, Topics))/binary>>.

%% ====================================================================
%% Internal functions
%% ====================================================================

encode_remaining_length(Length) ->
	encode_rl(Length, <<>>).

encode_rl(0, Result) -> Result;
encode_rl(L, Result) -> 
	Rem = L div 128,
	EncodedByte = (L rem 128) bor (if Rem > 0 -> 16#80; true -> 0 end), 
	encode_rl(Rem, <<Result/binary, EncodedByte:8>>).

