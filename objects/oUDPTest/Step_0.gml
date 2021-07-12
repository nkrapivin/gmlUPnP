/// @description check time.

var curtime = get_timer();

if (curtime - mystart > mytime) {
	event_user(0);
	mystart = curtime;
}

