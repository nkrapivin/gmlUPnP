/// @description Test.

/*  The whole process goes something like this:
 *  - First the MSearch callback is executed, we get a path to an IGD XML file.
 *  - Then we try to determine our local ip address via a broadcast.
 *  - After getting our IP, we download the IGD XML file and "parse" it.
 *  - After we found an important IPC URL in the IGD XML file, we try to get our WAN External IP.
 *  - Okay, we know our external IP, you can draw it in the main menu or whatever.
 *  - Then we actually ask the router nicely to open a port.
 *  - After opening a port, we start a simple TCP listener server, just as an example, and wait 15 secs.
 *  - After the time had passed, we ask the router to delete the port mapping.
 *  - After the port mapping has closed, you can return to main menu or idk.
 *
 */


drawString = undefined;
ip = "";
igdxml = "";

game_set_speed(0, gamespeed_fps);

targetport = 1337;
targetdesc = "gmlUPNP test application";

append = function() {
	for (var i = 0; i < argument_count; ++i)
		drawString += string(argument[i]);
		
	drawString += "\n";
};

clear = function() {
	drawString = "";	
};

onResult = function(e) {
	var _cbtype = e.getType();
	switch (_cbtype) {
		case UPNP_CALLBACK_TYPE.MSEARCH: {
			var mdat = e.getData();
			
			append("-- MSearch ok --");
			append("Server location: ", mdat.getLocation());
			append("Server agent: ", mdat.getServer());
			append();
			
			UPNP.determineLocalIp();
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
			
			UPNP.setIpcUrl(undefined); // don't parse the XML here, set it to default.
			UPNP.getExternalIp();
			
			break;
		}
		
		case UPNP_CALLBACK_TYPE.DELETE: {
			var ddat = e.getData();
			
			append("-- Port mapping deleted --");
			append("url: ", ddat.getUrl());
			append();
			
			break;
		}
		
		case UPNP_CALLBACK_TYPE.LOCAL: {
			var myip = e.getData().getIp();
			
			append("-- My local ip --");
			append("ip: ", myip);
			append();
			
			ip = myip;
			UPNP.getIgd();
			
			break;
		};
		
		case UPNP_CALLBACK_TYPE.EXTERNAL: {
			var myxml = e.getData().getXml();
			var myextip = gmlUPNP_parseExternalIp(myxml);
			
			append("-- my external ip --");
			append("ext. ip: ", myextip);
			
			UPNP.addMapping(ip, targetdesc, targetport, undefined, UPNP_PORT_PROTOCOL.TCP, undefined);
			break;
		};
		
		case UPNP_CALLBACK_TYPE.PORT: {
			var pdat = e.getData();
			
			append("-- Port mapping ok --");
			append("url: ", pdat.getUrl());
			append();
			
			// a typical sample network server (doesn't rely on any gmlUPNP stuff!)
			with (instance_create_layer(x, y, layer, oSampleServer)) {
				port = other.targetport;
				maxclients = 8;
			}
			
			append("-- Sample Server started, use ncat or nc or netcat... --");
			
			break;
		}
		
		default: {
			var wdat = e.getData();
			
			append("-- Weird callback --");
			append("Type: ", _cbtype);
			append("Data: ", wdat);
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

// now wait for the result in onResult...

// oh, let's take down the whole thing after 15 seconds.
mystart = get_timer();
mytime = 15 * 1000000;


