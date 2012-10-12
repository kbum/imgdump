#!/usr/bin/perl -w

# cumbrumber
# created 1/25/2012
# modified 3/20/2012

use strict;
use warnings;
use threads;
use threads::shared;
use id_core;
use Storable qw (nstore retrieve);

my $url;
my $dest;
my $name;
my $no_mkdir;
my $no_download;
my $config_param;
my $save_as;
my $modify_store;
my $from_file;

my $mode = $ARGV[0];

my %params = @ARGV;
my %params_def = (
   -dest => {
      assign   => \$dest,
      default  => "store/",
   },
   -url => {
      assign   => \$url,
   },
   -name => {
      assign  => \$name,
      default => 'default',
   },
   -save_as => {
      assign => \$save_as,
   },
   -no_mkdir => {
      assign  => \$no_mkdir,
      default => 0,
   },
   -no_download => {
      assign  => \$no_download,
      default => 0,
   },
   -config_type => {
      assign  => \$config_param,
   },

   # get store from file given in -from_file, modify, and save to
   # file given in -save_as
   -modify_store => {
      assign => \$modify_store,
      default => 0,
   },
   -from_file => {
      assign => \$from_file,
      default => 'net_store.ids',
   },
);

id_params::assign(\%params, \%params_def);

if (defined $mode && $mode eq 'config') { # configure store.ids
   my $quit = 0;

   sub _print_help { 
   print("\n id_run.pl   --- ImageDump ---\n\n"
      . "   From this user interface you can configure store.ids.\n"
      . "   choose an option from the list\n\n"
      . " PARAMS\n\n"
      . "   r      - id_store::remove()    - removes specified thread from\n"
      . "                                    specified store\n\n"
      . "   p      - id_store::print_all() - prints short version of\n"
      . "                                    store.ids contents\n\n"
      . "   P      - id_store::print_all('long') - prints the entire contents of\n"
      . "                                    store.ids\n\n"
      . "   h      - _print_help() - print the help text\n\n"
      . "   s      - id_store::save()      - save the changes made\n\n"
      . "   Q      - exit\n\n"
  
   );
   } # end of _print_help

   if (!defined $config_param) {
      _print_help();
   }
   $from_file = 'bin_store.ids';

   print "filename to load store from? default [$from_file]: ";
   my $file = <STDIN>;
   chomp $file;
   $from_file = $file if $file ne "";

   # get the thread info from store.ids
   print "loading store from file [$from_file]\n";
   my $main_store = new id_store();
   $main_store = ${retrieve($from_file);};

   while(!$quit) {
      my $choice;
      if (defined $config_param) {
         $choice = $config_param;
	      $quit = 1;
      }
      else {
         print "enter choice: ";
         $choice = <STDIN>;
      }
      
      if ($choice =~ /p/) {
         print "\n----- printing store.ids\n\n";
         $main_store->id_store::print_all();
      }
      elsif ($choice =~ /P/) {
         print "\n----- printing store.ids\n\n";
         $main_store->id_store::print_all(length => 'long');
      }

      elsif ($choice =~ /h/i) {
         _print_help();
      }

      elsif ($choice =~ /r/i) {
         print "thread to remove: ";
         $choice = <STDIN>;
         chomp($choice);

         $main_store->id_store::remove_thread(
            thread_name => $choice,
         );
      }
      
      elsif ($choice =~ /s/i) {
         my $save_file;
         $save_file = $save_as if defined $save_as;
         $save_file = $from_file if !defined $save_file;

         print "name to save file as? default is [$save_file]: ";
         $choice = 'default';
         $choice = <STDIN>;
         chomp($choice);

         $save_file = $choice if $choice ne 'default';

         $main_store->id_store::save(
            mode => 'data_dumper',
            filename => $save_file,
         );
      }
      
      elsif ($choice =~ /q/i) {
         exit;
      }

   }
}
elsif ($modify_store) {
   my $store = id_store->new();
   if (-f $from_file) {
      $store->id_store::read_all(
         filename => $from_file,
      );
   }
   else {
      print "id_run modify_store: could not find file ["
          . "$from_file]\n";
      exit;
   }

   foreach my $thread (@{$store->{_store}}) {
      $thread->id_thread::generate_xpms(
         fix_broken_xpms => 1,
      );
   }

   if (!defined $save_as) {
      $save_as = 'net_store.ids';
   }

   $store->id_store::save(
      mode => 'data_dumper',
      filename => $save_as,
      remove_xpms => 0,
   );
}
elsif (defined($mode) && $mode !~ /help|\-h/)  { 
   my $main_store = new id_store();
   $main_store = ${retrieve('bin_store.ids');};

   $main_store->id_store::download_images(
      url         => $url,
      dest        => $dest,
      name        => $name,
      save_as     => $save_as,
   );
}
else { # help

   print "\n id_run.pl   --- ImageDump ---\n\n"
       . "currently the parameters need to be given\n"
       . "in the correct order.\n"
       . "   perl id_run.pl url [destination] [no_mkdir] [no_download]\n\n"
       . " PARAMS\n\n"
       . "      -url         - string - required\n"
       . "                     the full address of the web page to be\n"
       . "                     downloaded.\n\n"
       . "      -dest        - string - default - /home/id/test/default/\n"
       . "                     directory to save the images to.\n"
       . "                     id will try to make the directory if\n"
       . "                     it doesn't exist.\n\n"
       . "      -name        - string - optional\n"
       . "                     name of the thread\n\n"
       . "      -save_as     - string - optional\n"
       . "                     filename to save the new thread info in.\n"
       . "                     net_store.ids is used for transfering new\n"
       . "                     thread info between server and client\n\n"
       . "      -no_mkdir    - (1/0) bool - default 0\n"
       . "                     tells id not to make directory. will fail\n"
       . "                     if it doesn't find the directory.\n\n"
       . "      -no_download - (1/0) bool - default 0\n"
       . "                     tells id not to run get_img at the end of\n"
       . "                     parse_page.\n\n";
}

exit;
