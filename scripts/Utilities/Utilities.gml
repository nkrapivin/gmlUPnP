
function DumpStringToFile(_filename, _contents) {
	var _file = file_text_open_write(_filename);
	if (_file < 0) {
		show_debug_message("Failed to create a file.");
		return false;
	}
	
	file_text_write_string(_file, _contents);
	file_text_close(_file);
	
	show_debug_message("Dumped text to file " + _filename + ", file handle = " + string(_file));
	_file = undefined;
	return true;
}
