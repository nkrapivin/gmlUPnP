/// @description Test.

drawString = undefined;

append = function() {
	for (var i = 0; i < argument_count; ++i)
		drawString += string(argument[i]);
		
	drawString += "\n";
};

clear = function() {
	drawString = "";	
};

onResult = function(e) {
	switch (e.getType()) {
		case UPNP_CALLBACK_TYPE.MSEARCH: {
			var mdat = e.getData();
			
			append("-- MSearch ok --");
			append("Server location: ", mdat.getLocation());
			append("Server agent: ", mdat.getServer());
			append();
			
			UPNP.addMapping("192.168.1.218", "gmlUPNP Test", 1337, UPNP_PORT_PROTOCOL.UDP);
			break;
		}
		
		case UPNP_CALLBACK_TYPE.PORT: {
			var pdat = e.getData();
			
			append("-- Port mapping ok --");
			append();
			break;
		}
		
		default: {
			var wdat = e.getData();
			
			append("-- Weird callback --");
			append("Type: ", e.getType());
			append("Data: ", e.getData());
			append();
			break;
		}
	}
};

clear();
append("gmlUPNP test");
UPNP.setCallback(onResult);
UPNP.startMSearch();
append("Searching for an IGD device...");
