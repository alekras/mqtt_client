# MQTT client (mqtt_client) 
(developing in process)

## How it works

### Build project 

```
Run Rebar3: 
$ rebar do version,compile
```

### Run some MQTT server like RabbitMQ or Mosquitto

### Go to directory `<mqtt_client dir>`/_build/test/lib/mqtt_client/ebin
```
$ cd <mqtt_client>/_build/test/lib/mqtt_client/ebin
```

### Open Erlang shell and run mqtt_client
```
1> application:start(mqtt_client).
 >>> start application normal []
ok
```

### Load record definition
```
2> rr("../include/mqtt_client.hrl").
[connect,connection_state,mqtt_client_error,publish]
```
### Establish connection to MQTT server
```
3>	Conn =
	mqtt_client:connect(
		test_client, 
		#connect{
			client_id = "test_client",
			user_name = "guest",
			password = <<"guest">>,
			will = 0,
			will_message = <<>>,
			will_topic = [],
			clean_session = 1,
			keep_alive = 1000
		}, 
		"localhost", 
		1883, 
		[]
	).
 >>> client <0.51.0> connected with response: "0x00 Connection Accepted", 
<0.51.0>
```

### Subscribe to topic and define callback function
```
4> mqtt_client:subscribe(Conn, [{"AKtest", 2, {fun(Arg) -> io:format(user, "Callback:: ~p", [Arg]) end}}]).
{suback,[1]}
```

### Publish message to server for yourself
```
5> mqtt_client:publish(Conn, #publish{topic = "AKtest"}, <<"Test Payload QoS = 0.">>).
{ok}
```

### Get response message thru callback function
```
6> Callback:: {"AKtest",<<"Test Payload QoS = 0.">>}
```

