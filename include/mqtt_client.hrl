-record(connect, 
  {
    client_id :: string(),
    user_name :: string(),
    password :: binary(),
    will_retain = false :: boolean(),
    will_qos = 0 :: 0 | 1 | 2,
    will :: binary(),
    will_topic :: string(),
    will_message :: binary(),
    clean_session = true :: boolean(),
    keep_alive :: integer()
  }
).

-record(publish,
	{
		topic :: string(),
		dup = 0 :: 0 | 1,
		qos = 0 :: 0 | 1 | 2,
		retain = 0 :: 0 | 1,
		acknowleged = none :: none | pubrec | pubrel
	}
).

-record(connection_state, 
  { socket :: port(),
		session_present :: 0 | 1,
		connected = 0 :: 0 | 1,
		packet_id = 100 :: integer(),
		subscriptions = #{} :: map(),
		processes = #{} :: map(),
		tail = <<>> :: binary(),
		ping_count = 0 :: integer()
  }
).

%% @type mqtt_client_error() = #mqtt_client_error{}. Record represents an exception that is thrown by a client's module.<br/> 
%% -record(<strong>mqtt_client_error</strong>, {
%% <dl>
%%   <dt>type:: tcp | connection</dt><dd>- .</dd>
%%   <dt>errno = none:: none | integer()</dt><dd>- .</dd>
%%   <dt>source = []::string()</dt><dd>- .</dd>
%%   <dt>message = []::string()</dt><dd>- .</dd>
%% </dl>
%% }).
-record(mqtt_client_error, 
  {
    type:: tcp | connection, 
    errno = none:: none | integer(),
    source = []::string(), 
    message = []::string()
  }
).

-define(BUFFER_SIZE, 16#4000).
-define(RECV_TIMEOUT, 60000).
-define(SEND_TIMEOUT, 60000).
-define(CONN_TIMEOUT, 60000).
-define(GEN_SERVER_TIMEOUT, 300000).

-define(CONNECT_PACK_TYPE, 16#10:8).
-define(CONNACK_PACK_TYPE, 16#20:8).
-define(PUBLISH_PACK_TYPE, 16#3:4).
-define(PUBACK_PACK_TYPE,  16#40:8).
-define(PUBREC_PACK_TYPE, 16#50:8).
-define(PUBREL_PACK_TYPE, 16#62:8).
-define(PUBCOMP_PACK_TYPE, 16#70:8).
-define(SUBSCRIBE_PACK_TYPE, 16#82:8).
-define(SUBACK_PACK_TYPE, 16#90:8).
-define(UNSUBSCRIBE_PACK_TYPE, 16#A2:8).
-define(UNSUBACK_PACK_TYPE, 16#B0:8).
-define(PING_PACK_TYPE, 16#C0:8).
-define(PINGRESP_PACK_TYPE, 16#D0:8).
-define(DISCONNECT_PACK_TYPE, 16#E0:8).
