/// @description Test.

drawString = undefined;
ip = "";
igdxml = "";

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
			
			UPNP.determineLocalIp();
			UPNP.getIgd();
			break;
		}
		
		case UPNP_CALLBACK_TYPE.IGD: {
			var idat = e.getData();
			
			igdxml = idat.getXml();
			
			append("-- IGD Response --");
			append("url: ", idat.getUrl());
			// append("xml: ", igdxml);
			append();
			
			DumpStringToFile("igd.xml", igdxml);
			
			break;
		}
		
		case UPNP_CALLBACK_TYPE.LOCAL: {
			var myip = e.getData().getIp();
			
			append("-- My local ip --");
			append("ip: ", myip);
			append();
			
			ip = myip;
			
			UPNP.addMapping(ip, "JS Rocks, hi from gmlUPnP", 1337, 1337, UPNP_PORT_PROTOCOL.TCP, 0);
			
			break;
		};
		
		case UPNP_CALLBACK_TYPE.PORT: {
			var pdat = e.getData();
			
			append("-- Port mapping ok --");
			append();
			
			with (instance_create_layer(x, y, layer, oSampleServer)) {
				port = 1337;
				maxclients = 8;
			}
			
			append("-- Sample Server started --");
			
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


// alarm[0] = 5 * game_get_speed(gamespeed_fps);
