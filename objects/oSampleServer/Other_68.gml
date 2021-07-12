/// @description react to us.

if (is_undefined(serv)) exit;

if (async_load[? "id"] == serv) {
	if (async_load[? "type"] == network_type_connect) {
		var mystring = "Hello " + string(async_load[? "ip"]) + ":" + string(async_load[? "port"]) + ", my random number is " + string(floor(seed / (1+irandom(10)))) + ", bye!\r\n";
		var mybuff = buffer_create(string_byte_length(mystring), buffer_fixed, 1);
		buffer_write(mybuff, buffer_text, mystring);
		buffer_seek(mybuff, buffer_seek_start, 0);
		
		network_send_raw(async_load[? "socket"], mybuff, buffer_get_size(mybuff));
		network_destroy(async_load[? "socket"]);
		buffer_delete(mybuff);
	}
}

