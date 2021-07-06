// Macroses:
#macro UPNP_IPV4_IP     "239.255.255.250"
#macro UPNP_IPV4_PORT   1900
#macro UPNP_MX          2
#macro UPNP_DEVICE_TYPE "urn:schemas-upnp-org:device:InternetGatewayDevice:1"

// Enums:
enum UPNP_CALLBACK_TYPE {
	UNDEFINED,
	MSEARCH,
	PORT,
	
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
	return ((portval > 0) && (portval < 65535));
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
	m_isMSearch = false;
	
	m_igd_location = "";
	m_igd_server = "";
	m_igd_usn = "";
	m_igd_st = "";
	
	// public:
	static setCallback = function(onStuff) {
		m_callback = onStuff;
		return self;
	};
	
	static addMapping = function(host, description, port, protocol) {
		// check arguments.
		if (!gmlUPNP_isValidPort(port)) {
			throw "Invalid `port` argument. Not a valid port.";	
		}
		
		if (protocol >= UPNP_PORT_PROTOCOL.MAX || protocol < 0) {
			throw "Invalid `protocol` argument. Not a valid network protocol.";	
		}
		
		if (!is_string(host)) {
			throw "Invalid `host` argument. Expected a string.";	
		}
		
		
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
		
		network_send_udp_raw(m_socket, UPNP_IPV4_IP, UPNP_IPV4_PORT, request, buffer_tell(request));
		buffer_delete(request);
		m_isMSearch = true;
		return true;
	};
	
	static processMap = function(the_async_load) {
		if (m_isMSearch) {
			m_isMSearch = false;
			network_destroy(m_socket);
			m_socket = -1;
			
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
			m_callback(_cbdata);
		}
	};
}


