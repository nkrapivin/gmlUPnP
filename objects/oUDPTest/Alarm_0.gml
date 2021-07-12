/// @description delete port mapping.

append("Deleting port mapping...");
UPNP.deleteMapping(1337, UPNP_PORT_PROTOCOL.TCP, ip);

