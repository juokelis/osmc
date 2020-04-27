import socket
import xbmc
import xbmcgui
import xbmcaddon

__addon__        = xbmcaddon.Addon()
__setting__      = __addon__.getSetting
DIALOG           = xbmcgui.Dialog()

def lang(id):
	san = __addon__.getLocalizedString(id)
	return san 

def log(message):
	xbmc.log(str(message), level=xbmc.LOGWARNING)


log('default started')


try:
	address = '/var/tmp/osmc.settings.sockfile'
	log('address: '+address)
	sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
	log('socket initiated')
	sock.connect(address)
	log('socket connected')
	sock.sendall('open'.encode())
	log('open sent')
	sock.close()

except OSError as e:
	log('default failed to open'+e.strerror)
	ok = DIALOG.ok(lang(32007), lang(32005), lang(32006))

log('default closing')


