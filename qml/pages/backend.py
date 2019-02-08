#!/usr/bin/env python
# -*- coding: utf-8 -*-

# import easywebdav
import re
import urllib
from urllib.request import urlretrieve
import ampyche
import os
import subprocess
import time
import threading
import http.server
import socketserver
import pyspotinterface

'''class RemoteServer:
	def __init__(self, host, protocol, username, password):
		self.host = host
		self.protocol = protocol
		self.port = 443 if protocol=='https' else 80
		self.path = "remote.php/webdav/"
		self.username = username
		self.password = password
		self.dav = None
		self.audio_list = []
		self.audio_dict = {}
	def connect(self):
		self.dav = easywebdav.connect(
			self.host,
			port=self.port,
			protocol=self.protocol,
			username=self.username,
			password=self.password,
			path=self.path)
	def scan(self, dir='/'):
		dirlisting = self.dav.ls(dir)
		for i in dirlisting[1:]:
			if i.name.endswith('/'):
				self.scan(i.name.replace('/'+self.path, '/', 1))
			elif i.contenttype in ['audio/mpeg']:
				self.audio_list.append(i.name.replace('/'+self.path, '/', 1))
				print(i.name.replace('/'+self.path, '/', 1))
	def parse_audio(self):
		for j in self.audio_list:
			i = urllib.parse.unquote(j)
			segments = i.split('/')
			try:
				# if '-' in segments[-2]:
				# 	artist, album = [k.strip() for k in segments[-2].split('-')][:2]
				# 	name = segments[-1].split('.mp3')[0]
				# else:
					artist = segments[-3]
					album = segments[-2]
					name = segments[-1].split('.mp3')[0]
			except IndexError:
				if '-' in segments[-1]:
					parts = segments[-1].split('-')
					if len(parts) == 3:
						artist, album, name = parts
					elif len(parts) == 2:
						artist, name = parts
						album = ""
					elif len(parts) > 3:
						artist = parts[0]
						album = parts[1]
						name = '-'.join(parts[2:])
					else:
						if ',' in segments[-1]:
							artist, name = segments[-1].split(',',num=1)
							album = ''
						else:
							artist, album = '', ''
							name = segments[-1]
				name = name.split('.mp3')[0]
			name = re.sub(r'(^[\w\- ]*\d+ ?[-.]? ?)', '', name)
			name = re.sub('_',' ', name)
			artist = artist.title().strip()
			album = album.title().strip()
			name = name.title().strip()
			self.audio_dict[j] = {'name':name, 'artist':artist, 'album':album}'''

server = None

ROOT_CACHE = os.path.expanduser('~')+'/.cache/oxidane/'
TMP_CACHE = '/tmp/oxidane/'
AUDIO_CACHE = ROOT_CACHE + 'audio/'
ART_CACHE = ROOT_CACHE + 'art/'
TMP_AUDIO_CACHE = TMP_CACHE + 'audio/'
TMP_ART_CACHE = TMP_CACHE + 'art/'
URL_PATH = "http://localhost:8090/"

currentsong = ""
transfers = []
http_mappings = {}

def copyfiles(infile, outfiles):
	while True:
		buf = infile.read(1024)
		if not buf:
			break
		for f in outfiles:
			f.write(buf)

class FixedHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):

	def do_GET(self):
		remote_url, local_url = self.send_head() 
		if remote_url:
			copyfiles(urllib.urlopen(remote_url), [self.wfile, local_url])
		elif local_url:
			self.copyfile(local_url, self.wfile)

	def send_head(self):
		path = self.path.strip('/')
		print (self.path)
		if path in os.listdir(AUDIO_CACHE):

			f = open(AUDIO_CACHE+path, 'rb')
			fs = os.fstat(f.fileno())
			self.send_response(200)
			self.send_header("Content-Type", "audio/mpeg")
			self.send_header("Content-Length", str(fs[6]))
			self.send_header("Last-Modified", self.date_time_string(fs.st_mtime))
			self.end_headers()
			return None, f
		else:
			try:
				url = http_mappings[path]
				req = urllib.request.urlopen(url)
				self.send_response(200)
				self.send_header("Content-Type", req.headers['Content-Type'])
				self.send_header("Content-Length", req.headers['Content-Length'])
				self.send_header("Last-Modified", req.headers['Last-Modified'])
				self.end_headers()
				return req, open(TMP_AUDIO_CACHE+path, 'wb')
			except urllib.error.HTTPError as e:
				self.send_error(e.code, e.msg)
				return None, None


	def log_request(self, code='-', size='-'):
		if code!=200:
			self.log_message('"%s" %s %s', self.requestline, str(code), str(size))

def setupoc(serverurl=None, username=None, password=None):
	global server
	if serverurl is None: serverurl = open("/home/nemo/.ocsv.txt").read().strip()
	if username is None: username = open("/home/nemo/.ocusr.txt").read().strip()
	if password is None: password = open("/home/nemo/.ocpwd.txt").read().strip()
	server = ampyche.AmpacheServer(serverurl, username, password)
	oc_playlists = server.playlists('')
	if not os.path.exists(ROOT_CACHE):
		os.makedirs(ROOT_CACHE)
		os.mkdir(AUDIO_CACHE)
		os.mkdir(ART_CACHE)
	if not os.path.exists(TMP_CACHE):
		os.makedirs(TMP_CACHE)
		os.mkdir(TMP_AUDIO_CACHE)
		os.mkdir(TMP_ART_CACHE)

	httpd = socketserver.TCPServer(("", 8090), FixedHTTPRequestHandler)
	httpdthread = threading.Thread(target=httpd.serve_forever)
	httpdthread.start()
	oclists = [j + ('oc',) for j in sorted(list({i.id: i.name for i in oc_playlists}.items()))]
	return oclists

def setupspot():
	spot_playlists = pyspotinterface.get_playlists(pyspotinterface.username)
	splists = [(i['id'], i['name'], 'spot') for i in spot_playlists]
	return splists

def search(search_string):
	song_results = server.songs(search_string)
	playlist_results = server.playlists(search_string)
	return [
		sorted(list({i.id: i.title for i in song_results}.items())),
		sorted(list({i.id: i.name for i in playlist_results}.items()))
	]

def loadPlaylist(pid, ptype):
	print ("Loading playlist "+str(pid))
	if ptype=="oc":
		songs = server.playlist_songs(str(pid))
		return [(i.id, i.title, i.artist, i.url, i.art, i.albumid, i.time, int(i.bitrate)*float(i.time)/8, 'oc') for i in songs]
	elif ptype=="spot":
		songs = pyspotinterface.get_songs_from_playlist(pyspotinterface.username, pid)
		return [(i['id'], i['name'], i['artist'], i['art'], i['albumid'], i['duration_ms']/1000, 0, 'spot') for i in songs]

def setSong(sid):
	global currentsong
	currentsong = sid

def downloadSong(url, sid, coverurl, albumid, ssize):
	transfer = {}
	art_path = ""
	songtransfer = None
	# if not os.path.exists(AUDIO_CACHE+str(sid)+'.mp3'):
	# 	songtransfer = subprocess.Popen(['curl', '-o', TMP_AUDIO_CACHE+str(sid)+'.mp3', '-s', url])
	# 	transfer['song'] = songtransfer
	# 	transfer['sid'] = str(sid)
	if not os.path.exists(ART_CACHE+str(albumid)):
		arttransfer = subprocess.Popen(['curl', '-o', TMP_ART_CACHE+str(albumid), '-s', coverurl])
		transfer['art'] = arttransfer
		transfer['albumid'] = albumid
	else:                                                                                                                                                                            
		art_path = ART_CACHE+str(albumid)
	if transfer:
		transfers.append(transfer)
	# if songtransfer:
	# 	while not os.path.exists(TMP_AUDIO_CACHE+str(sid)+'.mp3'):
	# 		res = songtransfer.poll()
	# 		if res is not None:
	# 			return [r"%%%ERROR|"+str(res)]
	# 		time.sleep(0.25)
	# 	for i in range(40):                                                                                                                                                               
	# 		if os.path.getsize(TMP_AUDIO_CACHE+str(sid)+'.mp3') > 200000 or songtransfer.poll() is not None:                                                                                                                                                                                                
	# 			http_mappings[sid] = [TMP_AUDIO_CACHE+str(sid)+'.mp3', ssize, url]
	# 			# return [TMP_AUDIO_CACHE+str(sid)+'.mp3',art_path]
	# 			return [URL_PATH+str(sid)+'.mp3']
	# 		time.sleep(0.25)
	# 	else:                                                                                                                                                                                                        
	# 		return [r"%%%ERROR|song not downloading"]
	http_mappings[str(sid)+'.mp3'] = [url]
	return [URL_PATH+str(sid)+'.mp3', art_path]

def check_transfers():
	to_delete = []
	for transfer in transfers:
		if "song" in transfer:
			retval = transfer['song'].poll()
			if retval is not None:                                                                                                                                                                                                    
				if currentsong != transfer['sid']:
					# TODO: do something clever with errors?
					subprocess.check_call(['mv', TMP_AUDIO_CACHE+transfer['sid']+'.mp3', AUDIO_CACHE+transfer['sid']+'.mp3'])
					del transfer['song']
					del transfer['sid']
		if "art" in transfer:
			retval = transfer['art'].poll()
			if retval is not None:
				# TODO: do something clever with errors?
				subprocess.check_call(['mv', TMP_ART_CACHE+transfer['albumid'], ART_CACHE+transfer['albumid']])
				del transfer['art']
				del transfer['albumid']
		if not transfer:
			to_delete.append(transfers.index(transfer))
	for doomed in reversed(to_delete):
		del transfers[doomed]
		print("Deleting empty transfer")

def press(number):
    number +=1
    return number

if __name__=="__main__":
	httpd = socketserver.TCPServer(("", 8090), FixedHTTPRequestHandler)
	httpd.serve_forever()
