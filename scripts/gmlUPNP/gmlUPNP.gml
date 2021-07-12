// Macroses:
#macro UPNP_IPV4_IP           "239.255.255.250"
#macro UPNP_IPV4_PORT         1900
#macro UPNP_MX                2
#macro UPNP_DEVICE_TYPE       "urn:schemas-upnp-org:device:InternetGatewayDevice:1"
#macro UPNP_LOCAL_PORT        30055 /* "gu" (as in gmlUPNP) in ASCII */
#macro UPNP_LOCAL_MAX_CLIENTS 64
#macro UPNP_USER_AGENT        "gmlUPNP/1.0 (GM_runtime_version; " + GM_runtime_version + ")"
#macro UPNP_SOAP_ACTION       "urn:schemas-upnp-org:service:WANIPConnection:1#AddPortMapping"
#macro UPNP_DELSOAP_ACTION    "urn:schemas-upnp-org:service:WANIPConnection:1#DeletePortMapping"

// Enums:
enum UPNP_CALLBACK_TYPE {
	UNDEFINED,
	MSEARCH,
	DELETE,
	PORT,
	SOAP,
	LOCAL,
	IGD,
	
	MAX
};

enum UPNP_PORT_PROTOCOL {
	UDP,
	TCP,
	
	MAX
}

// Functions:
/// @function gmlUPNP_makeBuffer(text)
/// @description Quickly turns a string into a buffer. Seek position is at the end.
/// @param {string} text Contents
/// @returns {buffer} buffer index
function gmlUPNP_makeBuffer(text) {
	var _text = string(text);
	var _buff = buffer_create(string_byte_length(_text), buffer_fixed, 1);
	buffer_write(_buff, buffer_text, _text);
	return _buff;
}

/// @function gmlUPNP_isValidPort(port)
/// @description Checks if the passed number is a valid internet port.
/// @param {real} port Port to check
/// @returns {bool} is number a valid port?
function gmlUPNP_isValidPort(portval) {
	return ((!is_undefined(portval)) && (portval > 0) && (portval < 65535));
}

/// @function gmlUPNP_protocolStringify(protocol)
/// @description Turns an UPNP_PORT_PROTOCOL enum value into a string.
/// @param {UPNP_PORT_PROTOCOL} enum value
/// @returns {string} TCP/UDP or an empty string on failure.
function gmlUPNP_protocolStringify(protvalue) {
	switch (protvalue) {
		case UPNP_PORT_PROTOCOL.TCP: return "TCP";
		case UPNP_PORT_PROTOCOL.UDP: return "UDP";
		default: return "";
	}
}

// Classes:
function gmlUPNPMSearch(_location, _server, _usn, _st) constructor {
	// private:
	m_location = _location;
	m_server = _server;
	m_usn = _usn;
	m_st = _st;
	
	// public:
	static getLocation = function() {
		return m_location;
	};
	
	static getServer = function() {
		return m_server;
	};
	
	static getUSN = function() {
		return m_usn;
	};
	
	static getST = function() {
		return m_st;	
	};
}

function gmlUPNPLocalIp(_ip) constructor {
	// private:
	m_ip = _ip;
	
	// public:
	static getIp = function() {
		return m_ip;	
	};
}

function gmlUPNPSOAPResponse(_myxml, _url) constructor {
	// private:
	m_xml = _myxml;
	m_url = _url;
	// TODO: add specific SOAP stuff here???
	
	// public:
	static getXml = function() {
		return m_xml;	
	};
	
	static getUrl = function() {
		return m_url;	
	};
}

function gmlUPNPIGDResponse(_theresponse, _theurl) constructor {
	// private:
	m_xml = _theresponse;
	m_url = _theurl;
	
	// public:
	static getXml = function() {
		return m_xml;	
	};
	
	static getUrl = function() {
		return m_url;	
	};
}

function gmlUPNPStringBuilder() constructor {
	// private:
	m_string = "";
	m_newline = "\r\n"; // UPnP requests use Windows newlines, please do not change this.
	
	// public:
	static append = function() {
		for (var i = 0; i < argument_count; ++i) {
			m_string += string(argument[i]);	
		}
		
		m_string += m_newline;
		
		return self;
	};
	
	static toString = function() {
		return m_string;	
	};
	
	static toBuffer = function() {
		return gmlUPNP_makeBuffer(toString());
	};
	
	static equals = function(the_other_thing) {
		if (is_string(the_other_thing)) {
			return m_string == the_other_thing;	
		}
		
		if (is_struct(the_other_thing)) {
			return m_string == the_other_thing.m_string;	
		}
		
		return m_string == string(the_other_thing);
	};
	
	static clear = function() {
		m_string = "";
		return self;
	};
}

function gmlUPNPCallbackData(_theType, _theData) constructor {
	// private:
	m_type = _theType;
	m_data = _theData;
	
	// public:
	static getType = function() {
		return m_type;	
	};
	
	static getData = function() {
		return m_data;	
	};
}

/// @function gmlUPNP()
/// @description Initializes a gmlUPNP class.
function gmlUPNP() constructor {
	// private:
	
	m_callback = undefined;
	m_socket = -1;
	m_buffer = -1;
	m_isMSearch = false;
	
	m_igd_location = "";
	m_igd_server = "";
	m_igd_usn = "";
	m_igd_st = "";
	
	m_igd_http = -1;
	
	m_local_srv = -1;
	m_local_sock = -1;
	m_local_contents = undefined;
	m_local_ip = "";
	
	m_soap_http = -1;
	
	// public:
	static setCallback = function(onStuff) {
		m_callback = onStuff;
		return self;
	};
	
	static getCallback = function() {
		return m_callback;	
	};
	
	static getRouterIp = function() {
		// this implementation is very hacky, but it does the job.
		var str1 = m_igd_location;
		str1 = string_replace(str1, "http://", "");
		str1 = string_copy(str1, 1, string_pos(":", str1) - 1);
		
		return str1;
	};
	
	static deleteMapping = function(port, protocol, host) {
		if (m_soap_http != -1) {
			throw "A SOAP request is already in action.";	
		}
		
		// check arguments.
		if (!gmlUPNP_isValidPort(port)) {
			throw "Invalid `port` argument. Not a valid port.";	
		}
		
		if (is_undefined(protocol) || protocol >= UPNP_PORT_PROTOCOL.MAX || protocol < 0) {
			throw "Invalid `protocol` argument. Not a valid network protocol.";	
		}
		
		if (!is_string(host)) {
			throw "Invalid `host` argument. Expected a string.";	
		}
		
		var reqstring = new gmlUPNPStringBuilder()
			.append("<?xml version=\"1.0\"?>")
				.append("<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">")
					.append("<s:Body>")
						.append("<u:DeletePortMapping xmlns:u=\"urn:schemas-upnp-org:service:WANIPConnection:1\">")
							.append("<NewRemoteHost>", host, "</NewRemoteHost>")
							.append("<NewExternalPort>", port, "</NewExternalPort>")
							.append("<NewProtocol>", gmlUPNP_protocolStringify(protocol), "</NewProtocol>")
						.append("</u:DeletePortMapping>")
					.append("</s:Body>")
				.append("</s:Envelope>")
			.toString();
			
		var hostport = getRouterIp() + ":" + string(UPNP_IPV4_PORT);	
		
		var hmap = ds_map_create();
		hmap[? "Host"] = hostport;
		hmap[? "User-Agent"] = UPNP_USER_AGENT;
		hmap[? "Cache-Control"] = "no-cache";
		hmap[? "Pragma"] = "no-cache";
		hmap[? "Content-Type"] = "text/xml";
		hmap[? "Connection"] = "Close";
		hmap[? "SOAPAction"] = UPNP_DELSOAP_ACTION;
		hmap[? "Content-Length"] = string_byte_length(reqstring);
		
		var httpreqid = http_request("http://" + hostport + "/ipc", "POST", hmap, reqstring);
		m_soap_http = httpreqid;
		
		return self;
	}
	
	static addMapping = function(host, description, port, intport, protocol, time) {
		if (m_soap_http != -1) {
			throw "A SOAP request is already in action.";	
		}
		
		// check arguments.
		if (!gmlUPNP_isValidPort(port)) {
			throw "Invalid `port` argument. Not a valid port.";	
		}
		
		var realintport = intport;
		if (!gmlUPNP_isValidPort(realintport)) {
			realintport = port;	
		}
		
		var realtime = time;
		if (is_undefined(realtime) || realtime < 0) {
			realtime = 0;
		}
		
		if (is_undefined(protocol) || protocol >= UPNP_PORT_PROTOCOL.MAX || protocol < 0) {
			throw "Invalid `protocol` argument. Not a valid network protocol.";	
		}
		
		if (!is_string(host)) {
			throw "Invalid `host` argument. Expected a string.";	
		}
		
		var reqstring = new gmlUPNPStringBuilder()
			.append("<?xml version=\"1.0\"?>")
				.append("<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">")
					.append("<s:Body>")
						.append("<u:AddPortMapping xmlns:u=\"urn:schemas-upnp-org:service:WANIPConnection:1\">")
							.append("<NewRemoteHost></NewRemoteHost>")
							.append("<NewExternalPort>", port, "</NewExternalPort>")
							.append("<NewProtocol>", gmlUPNP_protocolStringify(protocol), "</NewProtocol>")
							.append("<NewInternalPort>", realintport, "</NewInternalPort>")
							.append("<NewInternalClient>", host, "</NewInternalClient>")
							.append("<NewEnabled>1</NewEnabled>")
							.append("<NewPortMappingDescription>", description, "</NewPortMappingDescription>")
							.append("<NewLeaseDuration>", realtime, "</NewLeaseDuration>")
						.append("</u:AddPortMapping>")
					.append("</s:Body>")
				.append("</s:Envelope>")
			.toString();
		
		var hostport = getRouterIp() + ":" + string(UPNP_IPV4_PORT);
		
		var hmap = ds_map_create();
		hmap[? "Host"] = getRouterIp() + ":" + string(UPNP_IPV4_PORT);
		hmap[? "User-Agent"] = UPNP_USER_AGENT;
		hmap[? "Cache-Control"] = "no-cache";
		hmap[? "Pragma"] = "no-cache";
		hmap[? "Content-Type"] = "text/xml";
		hmap[? "Connection"] = "Close";
		hmap[? "SOAPAction"] = UPNP_SOAP_ACTION;
		hmap[? "Content-Length"] = string_byte_length(reqstring);
		
		var httpreqid = http_request("http://" + hostport + "/ipc", "POST", hmap, reqstring);
		m_soap_http = httpreqid;
		
		return self;
	};
	
	static determineLocalIp = function() {
		// using some magic broadcast fuckery to determine who we are.
		m_local_contents = new gmlUPNPStringBuilder()
			.append("gmlUPnP Broadcast id=" + string(get_timer()));
		// at first I wanted to call irandom() but then realized this may screw with games
		// that rely on a particular RNG state, okay then, get_timer() works well enough too.
		// we don't need this number to be cryptographically random or anything. just a number to determine two instances apart.
		
		// the docs say that the server must be TCP, and socket must be UDP
		// no idea why and I don't want to know why...
		m_local_sock = network_create_socket_ext(network_socket_udp, UPNP_LOCAL_PORT);
		m_local_srv = network_create_server_raw(network_socket_tcp, UPNP_LOCAL_PORT, UPNP_LOCAL_MAX_CLIENTS);
		
		var buff = m_local_contents.toBuffer();
		m_buffer = buff;
		var reqsize = buffer_tell(buff);
		
		while (network_send_broadcast(m_local_srv, UPNP_LOCAL_PORT, buff, reqsize) < 0) {
			show_debug_message("[gmlUPnP]: Retrying broadcast...");
		}
		
		// buffer_delete(buff);
		
		return self;
	};
	
	static getIgd = function() {
		if (m_igd_http == -1) {
			m_igd_http = http_get(m_igd_location);
			return self;
		}
		
		throw "An IGD request is already in action.";
	};
	
	static startMSearch = function() {
		if (m_isMSearch) return false;
		
		m_socket = network_create_socket(network_socket_udp);
		var request = new gmlUPNPStringBuilder()
			.append("M-SEARCH * HTTP/1.1")
			.append("HOST: ", UPNP_IPV4_IP, ":", UPNP_IPV4_PORT)
			.append("ST: ", UPNP_DEVICE_TYPE)
			.append("MAN: \"ssdp:discover\"")
			.append("MX: ", UPNP_MX)
			.append()
			.toBuffer();
			
		m_buffer = request;
		
		var requestsize = buffer_tell(request);
		
		while (network_send_udp_raw(m_socket, UPNP_IPV4_IP, UPNP_IPV4_PORT, request, requestsize) < 0) {
			show_debug_message("[gmlUPnP]: Retrying MSearch request... requestsize = " + string(requestsize));
		}
		
		// buffer_delete(request);
		m_isMSearch = true;
		return true;
	};
	
	static processHttp = function(the_async_load) {
		if (the_async_load[? "id"] == m_igd_http) {
			if (the_async_load[? "status"] == 0 && the_async_load[? "http_status"] == 200 && string_length(the_async_load[? "result"]) > 1) {
				var _hresult = the_async_load[? "result"];
				var _hurl = the_async_load[? "url"];
				
				// dispatch a callback
				var _igdxml = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.IGD, new gmlUPNPIGDResponse(_hresult, _hurl));
				(getCallback())(_igdxml);
				
				return self;
			}
		}
		
		if (the_async_load[? "id"] == m_soap_http) {
			m_soap_http = -1;
			if (the_async_load[? "status"] == 0 && the_async_load[? "http_status"] == 200 && string_length(the_async_load[? "result"]) > 1) {
				var myxml = the_async_load[? "result"];
				var myurl = the_async_load[? "url"];
				
				if (string_count("AddPortMapping", myxml) > 0) {
					// dispatch a callback
					var _soapadddata = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.PORT, new gmlUPNPSOAPResponse(myxml, myurl));
					(getCallback())(_soapadddata);
				}
				else if (string_count("DeletePortMapping", myxml) > 0) {
					// dispatch a callback
					var _soapdeldata = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.DELETE, new gmlUPNPSOAPResponse(myxml, myurl));
					(getCallback())(_soapdeldata);
				}
				else {
					// dispatch a callback
					var _soapdata = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.SOAP, new gmlUPNPSOAPResponse(myxml, myurl));
					(getCallback())(_soapdata);
				}
				
				
				return self;
			}
		}
		
		return undefined;
	};
	
	static processMap = function(the_async_load) {
		if (!is_undefined(m_local_contents) && m_buffer > -1 && the_async_load[? "type"] == network_type_data && the_async_load[? "id"] == m_local_sock) {
			var bcontents = buffer_read(the_async_load[? "buffer"], buffer_string);
			if (m_local_contents.equals(bcontents)) {
				// free EVERYTHING related to broadcasts...
				m_local_contents = undefined;
				network_destroy(m_local_srv);
				m_local_srv = -1;
				network_destroy(m_local_sock);
				m_local_sock = -1;
				buffer_delete(m_buffer);
				m_buffer = -1;
				
				// backup
				m_local_ip = the_async_load[? "ip"];
				
				// dispatch a callback
				var _ipcbdata = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.LOCAL, new gmlUPNPLocalIp(m_local_ip));
				(getCallback())(_ipcbdata);
			}
		}
		
		if (m_isMSearch) {
			m_isMSearch = false;
			network_destroy(m_socket);
			m_socket = -1;
			buffer_delete(m_buffer);
			m_buffer = -1;
			
			var mresponse = buffer_read(the_async_load[? "buffer"], buffer_string);
			
			// parse the response, this is essentially a key value pair with windows newlines
			
			/*
			HTTP/1.1 200 OK\r\n
			KEY: VALUE\r\n
			\r\n
			*/
			var __f = file_text_open_from_string(mresponse);
			var _httpOk = file_text_read_string(__f);
			file_text_readln(__f);
			if (_httpOk != "HTTP/1.1 200 OK") {
				throw "UPnP response was invalid.";
			}
			
			while (!file_text_eof(__f)) {
				var _line = file_text_read_string(__f);
				file_text_readln(__f);
				
				var _colon = string_pos(":", _line);
				var _key = string_copy(_line, 1, _colon - 1);
				var _value = string_delete(_line, 1, string_length(_key) + 2);
				
				switch (_key) {
					case "LOCATION": {
						m_igd_location = _value;
						break;
					}
					
					case "SERVER": {
						m_igd_server = _value;
						break;	
					}
					
					case "USN": {
						m_igd_usn = _value;
						break;
					}
					
					case "ST": {
						m_igd_st = _value;
						break;
					}
					
					default: {
						// TODO: implement other values?
						break;	
					}
				}
			}
			
			file_text_close(__f);
			
			// dispatch a callback:
			var _cbdata = new gmlUPNPCallbackData(UPNP_CALLBACK_TYPE.MSEARCH, new gmlUPNPMSearch(m_igd_location, m_igd_server, m_igd_usn, m_igd_st));
			(getCallback())(_cbdata);
		}
	};
}


