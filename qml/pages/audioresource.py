from ctypes import *
import time
import threading

a = cdll.LoadLibrary("/usr/lib/libaudioresource.so.1")
StatCB = CFUNCTYPE(None, c_void_p, c_bool, c_void_p)
init = a.audioresource_init
init.argtypes = [c_int, StatCB, c_void_p]
init.restype = c_void_p

CALLBACK = None
AUDIO_RESOURCE_MEDIA = 2

inited = False
is_acquired = False
resource = None
mainthread = None
dying = False

def _callback(resource, acquired, data):
	global is_acquired
	CALLBACK(acquired)
	if acquired:
		is_acquired = True
	else:
		is_acquired = False

callbackref = StatCB(_callback)

def glib_mainloop():
	while not dying:
		a.g_main_context_iteration(None, False)


def acquire(callback=None):
	global CALLBACK
	global resource
	global inited
	global mainthread
	if not inited:
		if not callable(callback):
			raise TypeError(str(type(callback)) + " is not callable")
		mainthread = threading.Thread(target=glib_mainloop)
		mainthread.start()
		CALLBACK = callback
		resource = init (AUDIO_RESOURCE_MEDIA, callbackref, None)
		inited = True
	a.audioresource_acquire(resource)
	while not is_acquired:
		# a.g_main_context_iteration(None, False)
		time.sleep(0.01)

def release():
	a.audioresource_release(resource)
	is_acquired = False
	while is_acquired:
		# a.g_main_context_iteration(None, False)
		time.sleep(0.01)

def free():
	global dying
	if is_acquired:
		release()
	a.audioresource_free(resource)
	dying = True
	mainthread.join()
