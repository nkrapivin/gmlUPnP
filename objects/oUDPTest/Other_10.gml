/// @description delete port mapping.

if (ip != "") {
	append("Deleting port mapping...");
	UPNP.deleteMapping(targetport, UPNP_PORT_PROTOCOL.TCP, ip);
}
else {
	append("Uh oh, try restarting the sample?");	
}
