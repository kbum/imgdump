#!/usr/bin/env python

# dale says, "create a layer 2 tunneling protocol socket."

from socket import *
from subprocess import call
#from os import system
import os
import re
import time
from sys import argv

IP = '' # ip address of the server
PORT = 5000 # port server is listening on
ADS = (IP, PORT)

tcpsoc = socket(AF_INET, SOCK_STREAM)
tcpsoc.connect(ADS)

params = ' '.join(argv)

tcpsoc.send(params)
time.sleep(1)
tcpsoc.send('END_OF_CMD')
data = ''
while 1:
   data_package = tcpsoc.recv(4096)
   if data_package == 'END_OF_CMD':
      break
   else:
      data += data_package
#data = tcpsoc.recv(1024)
if not data: exit

arguments = re.findall('\S+', data)
print('chat_client recieved arguments [', ' '.join(arguments), ']')

# parse the data

if arguments[0] == 'SENDING_NET_STORE':
   print('writing to net_store.ids')
   local_file = open('net_store.ids', 'wb')

   tcpsoc.send('ready')

   stored_data = ''
   count = 1
   # recieve the file in 4kb chunks
   while 1:
      data = tcpsoc.recv(4096)
#      print 'data recieved: [%s]\n\n' % data
      if data == 'END_OF_FILE':
         break
      else:
         print('got [%s] packet' % count)
         count += 1
         stored_data += data
 
   local_file.write(stored_data)
   print('chat_server finished')
   local_file.close()

if arguments[0] == 'SENDING_XPMS':

   print('recieving xpms')
   arguments[0] = ''

   for xpm_name in arguments:
      if xpm_name:
         # tell chat_server we're ready for the file
         tcpsoc.send('ready')
      
         print('writing xpm [%s] to disk' % xpm_name)

         # make sure we use the right file separators
         head, tail = os.path.split(xpm_name)
         file_path = os.path.join(head, tail)

         local_file = open(file_path, 'wb')
         stored_data = ''
         count = 1
         # recieve the file if 4kb chunks
         while 1:
            data = tcpsoc.recv(4096)
            if data == 'END_OF_FILE':
               break
            else:
               count += 1
               stored_data += data
         
         local_file.write(stored_data)
         local_file.close()
if arguments[0] == 'RECIEVING_STORE':
   print('sending store [', arguments[1], ']')
   
#   local_file = open(arguments[1])

tcpsoc.close()

