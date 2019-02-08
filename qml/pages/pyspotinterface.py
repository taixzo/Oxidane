import getpass
import librespot
import spotipy
import threading
import time
from spotipy.oauth2 import SpotifyClientCredentials

try:
	import audioresource
except (ImportError, OSError):
	class audioresource(object):
		def acquire(callback=None):
			pass
		def release():
			pass
		def free():
			pass

client_id = '95fa93da04ae46d3b4e7800a654c0f6e'
client_secret = open("/home/nemo/.spot_client_secret").read().strip()
ccm = SpotifyClientCredentials(client_id=client_id, client_secret=client_secret)
sp = spotipy.Spotify(client_credentials_manager=ccm)


pwd = open('/home/nemo/.spot_pwd', 'r').read().strip()
# pwd = getpass.getpass()
username = open('/home/nemo/.spot_usn').read().strip()

spot = librespot.connect(username, pwd)

playlist = []
pointer = 0
pystate = "Stopped"

def parse_tracks(tracks, output):
	for track in tracks['items']:
		output.append({
			'name': track['track']['name'],
			'artist': ', '.join([i['name'] for i in track['track']['artists']]),
			'art': track['track']['album']['images'][0]['url'],
			'albumid': track['track']['album']['id'],
			'duration_ms': track['track']['duration_ms'],
			'id': track['track']['id']
		})

def get_playlists(username):
	playlists = sp.user_playlists(username)
	return [{'name':i['name'], 'id':i['id']} for i in playlists['items'] if i['owner']['id']==username]

def get_songs_from_playlist(username, id):
	results = sp.user_playlist(username, id, fields="tracks,next")
	tracks = []
	stracks = results['tracks']
	parse_tracks(stracks, tracks)
	lastnext = ''
	while stracks['next'] and stracks['next']!=lastnext:
		lastnext = stracks['next']
		stracks = sp.next(results['tracks'])
		parse_tracks(stracks, tracks)
	return tracks

def play_song_from_playlist():
	audioresource.acquire()
	spot.stop()
	spot.play(playlist[pointer]["id"])
	print ("Playing %s - %s" % (playlist[pointer]['artist'], playlist[pointer]['name']))

def play_next():
	global pointer
	global pystate
	pointer += 1
	if pointer < len(playlist):
		pystate="Stopped"
		play_song_from_playlist()
		time.sleep(0.2)
		pystate="Playing"
	else:
		pointer = 0
		pystate="Stopped"

def play_prev():
	global pointer
	global pystate
	pointer -= 1
	if pointer >= 0 and playlist:
		play_song_from_playlist()
	else:
		pointer = 0
		pystate="Stopped"

def pause():
	global pystate
	if pystate=="Playing":
		audioresource.release()
		spot.pause()
		pystate = "Paused"
	elif pystate=="Paused":
		audioresource.acquire()
		spot.resume()
		pystate = "Playing"

def callback(is_acquired):
	if is_acquired:
		pass
	elif pystate=="Playing":
		spot.pause()
		pystate = "Paused"

def check_updates(fn):
	global pystate
	while True:
		time.sleep(0.1)
		state, offset = spot.get_state()
		if state=="Stopped" and pystate=="Playing":
			play_next()
		elif state=="Playing":
			pystate="Playing"
		if fn is not None:
			fn(state, offset)

def thread_updates(fn=None):
	upd_thread = threading.Thread(target=check_updates, args=(fn,))
	upd_thread.start()

"""
ps.spot.play("23TXSzmuErPA3CAPsE2bme")
ps.spot.pause()
ps.spot.resume()

import audioresource
def callback(ac):
  if not ac:
    spot.pause()
    print ("Lost resource - Pausing!")
  else:
    print ("Good to go!")

import getpass
import librespot
pwd = getpass.getpass()

spot = librespot.connect(username, pwd)
"""
