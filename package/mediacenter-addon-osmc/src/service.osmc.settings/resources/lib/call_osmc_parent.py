import sys
import xbmc
import socket

if len(sys.argv) > 1:

	msg = sys.argv[1]

	xbmc.log('OSMC settings sending response, %s' % msg, xbmc.LOGDEBUG)

	address = '/var/tmp/osmc.settings.sockfile'

	sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
	sock.connect(address)

	sock.sendall(msg.encode())
	sock.close()

	xbmc.log('OSMC settings sent response, %s' % msg, xbmc.LOGDEBUG)
