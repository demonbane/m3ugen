#!/usr/bin/perl

# m3ugen - Recursive, multi-format m3u generation tool
# (c) 2004 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

use Audio::File;
use Cwd;
use File::Basename;
use File::Find;
use Getopt::Mixed 1.006;
use IO::Handle;

Getopt::Mixed::init("r recursive>r n no-path>n h help>h usage>h d debug>d a albums>a");
$Getopt::Mixed::ignoreCase = 0;
Getopt::Mixed::getOptions();

if ($opt_h) {
  print "Usage: m3ugen [OPTION]... SOURCE [M3UFILE]\n";
  print "Output an m3u playlist containing mp3, Ogg Vorbis, and FLAC files found in\n";
  print "SOURCE to M3UFILE if specified, STDOUT otherwise.\n\n";
  print "  -h, --help         display this screen and exit\n\n";
  print "  -r, --recursive    recursively search through directories\n";
  print "                     (default is specified directory ONLY)\n\n";
  print "  -a, --albums       create ALBUMNAME.m3u for each album in SOURCE\n";
  print "                     (implies M3UFILE behavior and ignores M3UFILE if specified)\n\n";
  print "  -n, --no-path      print paths relative to SOURCE\n";
  print "                     (default is to print full path)\n\n";
  print "  -d, --debug        print debugging output to STDERR\n\n";
  exit 0;
}

if (!$ARGV[0]) {
  die "Please specify a directory to work on!\n\n";
}elsif (!-d $ARGV[0]) {
  die "Invalid directory!\n\n";
}

if ($ARGV[1]) {
  open(OUTPUT,">".$ARGV[1]) || die "Could not open $ARGV[1] for writing!\n";
}else {
  OUTPUT->fdopen(STDOUT, "w") || die "Could not redirect output!\n";
}

open(ERROR,">/dev/null");

if ($opt_d) {
  ERROR->fdopen(STDERR, "w");
}

print ERROR "SOURCE = \"$ARGV[0]\"\nM3UFILE = \"$ARGV[1]\"\n";

$workDir = Cwd::abs_path($ARGV[0])."/";

$currentDir = getcwd();

#for creating unique track numbers
$uniq = 1;

if (substr($workDir,0,1) ne '/') {
  $workDir = getcwd()."\/".$workDir;
}

if ($opt_r) {
  find(\&wanted, $workDir);
}else {
  chdir($workDir);
  foreach (glob("*.[Oo][Gg][Gg]"),glob("*.[Ff][Ll][Aa][Cc]"),glob("*.[Mm][Pp]3")) {
    print ERROR "found file = \"$_\"\n";
    push(@files,$workDir.$_);
  }
#  push(@files,glob("*.[Oo][Gg][Gg]"));
#  push(@files,glob("*.[Ff][Ll][Aa][Cc]"));
#  push(@files,glob("*.[Mm][Pp]3"));
}

foreach $filename (@files) {
  my $mediaFile = Audio::File->new("$filename");
  $track = abs($mediaFile->tag->track());
  $title = $mediaFile->tag->title();
  $artist = $mediaFile->tag->artist();
  $album = $mediaFile->tag->album();
  $length = $mediaFile->audio_properties->length();

  if (!$track || !$album) {
    $album = "Unknown Album Name";
    $track = $uniq++;
  }

  $m3ulines = "#EXTINF:".$length.",".$artist." - ".$title."\n";
  if ($opt_n) {
    $m3ulines .= ($filename ^ $workDir);
  }else {
    $m3ulines .= $filename;
  }
  $m3ulines .= "\n";

  $writeme{$album}[$track - 1] = $m3ulines;
  print ERROR "m3ulines = \"$m3ulines\"\n";
}

# This would be cleaner with an 'if' inside the 'foreach', but this way
# we eliminate an additional conditional check with each and every pass.
if ($opt_a) {
  print ERROR "Generating -a list\n";
  foreach $albumname (keys %writeme) {
    print ERROR "albumname = \"$albumname\"\n";
    close OUTPUT;
    open(OUTPUT,">$currentDir/$albumname.m3u") || die "Could not open $albumname.m3u for writing!\n";
    print OUTPUT "#EXTM3U\n";
    foreach $songname (@{$writeme{$albumname}}) {
      print ERROR "songname = \"$songname\"\n";
      print OUTPUT $songname;
    }
  }
}else{
  print ERROR "Generating standard list\n";
  print OUTPUT "#EXTM3U\n";
  foreach $albumname (keys %writeme) {
    print ERROR "albumname = \"$albumname\"\n";
    foreach $songname (@{$writeme{$albumname}}) {
      print ERROR "songname = \"$songname\"\n";
      print OUTPUT $songname;
    }
  }
}

close ERROR;
close OUTPUT;

sub wanted {
  if (-f $_) {
    print ERROR "-----------------\n";
    print ERROR "checking \"$_\"\n";
    my @fileParts = split(/\./);
    my $fileExt = lc(pop(@fileParts));
    print ERROR "fileExt = \"$fileExt\"\n";
    if ($fileExt eq "ogg" || $fileExt eq "flac" || $fileExt eq "mp3") {
      print ERROR "adding \"$_\" to \@files\n";
      push(@files, $File::Find::name);
    }
  }
}
