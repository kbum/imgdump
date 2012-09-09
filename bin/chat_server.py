#!/usr/bin/env python

from socket import *
from time import time, ctime
from subprocess import call

import time
import os
import subprocess
import re 

import string

IP = '' # ip address of the server
PORT = 5000 # port to listen on
ADS = (IP, PORT)

tcpsoc = socket(AF_INET, SOCK_STREAM)
tcpsoc.bind(ADS)
tcpsoc.listen(5)

while 1:
   print "Waiting for connection"
   tcpcli, addr = tcpsoc.accept()
   print "connected from:", addr
   
   while 1:
      data = ''
      while 1:
         data_package = tcpcli.recv(4096)
         if data_package == 'END_OF_CMD':
            break
         else:
            data += data_package
      
      if not data : break
      print 'data being recieved: [%s]' % (data)

      arguments = re.findall('\S+', data)
      
      pattern = re.compile('.*chat_client\.py')
      if pattern.match(arguments[0]):
   
         # options are id_run.pl, request_net_store
         match = re.search(r'id_run.pl', data)
         match2 = re.search(r'request_net_store', data)
         match3 = re.search(r'request_xpms', data)
         match4 = re.search(r'modify_store', data)
         
         # if argument 2 is id_run.pl
         if match:

            modify_store = 0
            file_name = 0
            count = 0
#            while 1:
#               if arguments[count]:
            for arg in arguments:
               if arg == '-modify_store':
                  modify_store = arguments[count + 1]
                  print arguments[count + 1]
               if arg == '-from_file':
                  file_name = arguments[count + 1]
               count += 1

            # if id_run.pl -modify_store 1 then the client is going 
            # to send an id_store object. save the object to filename
            # in -from_file, default filename is net_store.ids
            if modify_store:
               if not filename:
                  filename = 'net_store.ids'

               flag = 'RECIEVING_STORE ', file_name
               tcpcli.send(flag)

               break
               
               data = ''
               while 1:
                  data = tcpcli.recv(4096)
                  if data == 'END_OF_FILE':
                     break
                  else:
                     store_data += data
               
               local_file = open(file_name, 'wb')
               local_file.write(stored_data)
               local_file.close()

            arguments[0] = 'perl'
            all_args_str = ' '.join(arguments)

            print '[cmd]: [%s] ' % ' '.join(arguments)

            subprocess.call(arguments,)

            tcpcli.send('finished running')
            time.sleep(1)
            tcpcli.send('END_OF_CMD')

         # if argument 2 is request_net_store
         elif match2:
            print 'sending net_store.ids'
            net_store = open("net_store.ids", "rb")
            store_data = net_store.read()

            tcpcli.send('SENDING_NET_STORE')
            time.sleep(1)
            tcpcli.send('END_OF_CMD')
            data = tcpcli.recv(1024)
            if not re.search('ready', data):
               print 'client did not respond after prompt'
               break
            tcpcli.sendall(store_data)
            time.sleep(1)
            tcpcli.send('END_OF_FILE')


         # if argument 2 is request_xpms
         elif match3:
            print 'sending xpms'
            arguments[0] = ''
            arguments[1] = ''
            flag = 'SENDING_XPMS %s' % ' '.join(arguments)
            tcpcli.sendall(flag)
            time.sleep(.1)
            tcpcli.send('END_OF_CMD')
            for xpm_name in arguments:
               if xpm_name:
                  data = tcpcli.recv(1024)
                  match = re.search('ready', data)
                  if not match:
                     print 'client didn\'t respond after promp'
                     break

                  directories = re.findall('[\w\.]+', xpm_name)
                  file_path = '/'.join(directories)
                  print 'sending file: ', file_path

                  fileh = open(file_path, "rb")
                  image_data = fileh.read()
                  fileh.close()

                  tcpcli.send(image_data)
                  time.sleep(1)
                  tcpcli.send('END_OF_FILE')

         tcpcli.close()
         break
      # if argument 2 is modify_store
      elif match4:
         print 'modifying store given by client'
         flag = 'RECIEVING_STORE'
         tcpcli.sendall(flag)
         time.sleep(.1)
         tcpcli.send('END_OF_CMD')
         data = ''

         while 1:
            data_package = tcpcli.recv(1024)
            if data_package == 'END_OF_CMD':
               break
            else:
               data += data_package
         if not data: exit

         

      else:
         print "unknown arguments: "
         print ''.join(data)
#         print data
         data1 = "go away"
         tcpcli.send(data1)
         tcpcli.close()
         tcpsoc.close
         break
tcpsoc.close()
