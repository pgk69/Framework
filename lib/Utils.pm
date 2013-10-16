package Utils;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date: 2013-07-31 14:09:14 +0200 (Mi, 31. Jul 2013) $
#                       $Revision: 1069 $
#                       $Author: xck90n1 $
#
# Aufgabe:				- Toolboox
#
# $Id: Utils.pm 1069 2013-07-31 12:09:14Z xck90n1 $
# $URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/Utils.pm $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;
use open      qw(:utf8 :std);    # undeclared streams in UTF-8

use base 'Exporter';

our @EXPORT = qw(rel2Abs datum extendString hmap deep_keys_foreach getPsefData uniqueName);
#                 %var $PRG $DB $Bin
#                 $data_source $dbh $stmt $sth $fields $where $DBtime);
our @EXPORT_OK = ();

use vars @EXPORT, @EXPORT_OK;
#use vars qw(%var $PRG $DB $Bin);

use FindBin qw($Bin $Script $RealBin $RealScript);
use File::Spec;
use File::Path qw(mkpath);
use Time::HiRes qw(gettimeofday);
# use Fcntl;

# Globaler Hash zur Speicherung diverser Informationen
#%var = (
#  '$$'        => $$,
#  'script'    => $Script,
#  'Errorcode' => 0,
#  'Errortext' => ''
#);

# Programmparameter
#( $PRG, $DB ) = ( '', '' );

# Zugriff auf die Datenbank
# use DBI;
# my ( $data_source, $dbh, $stmt, $sth, $fields, $where, $DBtime );

sub uniqueName {
  #################################################################
  my ( $log, $mode ) = @_;

  # Test, ob einer der Schluesselworte in dem Dateinamen vorkommt.
  # Falls ja, Ersetzung mit dem aktuellen Wert
  if ( !$mode ) {
    my ($nano, $sekunde, $minute, $stunde, $tag, $wtag, $monat, $jahr) = datum(4);
    $log =~ s/\:\:Jahr\:\:/$jahr/g;
    $log =~ s/\:\:Monat\:\:/$monat/g;
    $log =~ s/\:\:Tag\:\:/$tag/g;
    $log =~ s/\:\:Stunde\:\:/$stunde/g;
    $log =~ s/\:\:Minute\:\:/$minute/g;
    $log =~ s/\:\:Sekunde\:\:/$sekunde/g;
  } else {
    $log =~ s/\:\:Jahr\:\://g;
    $log =~ s/\:\:Monat\:\://g;
    $log =~ s/\:\:Tag\:\://g;
    $log =~ s/\:\:Stunde\:\://g;
    $log =~ s/\:\:Minute\:\://g;
    $log =~ s/\:\:Sekunde\:\://g;
  }
  $log =~ /^(.*)$/;
  return $1;
}

sub datum {
  #################################################################
  #     Ermitteln des Datums
  my ($mode) = shift() || 0;

# ohne MODE: DD.MM.JJJJ hh:mm:ss.nnnn
# MODE 1   : JJMMTT hhmmssnnnn
# MODE 2   : JJMMTThh
# MODE 3   : JJJJ-MM-DD hh:mm:ss
# MODE 4   : ARRAY (Nanosekunde, Sekunde, Minute, Stunde, Tag, Wochentag, Monat, Jahr)
# MODE 5   : nnnnssmmhhTTMMJJ

  my $nano = substr( (gettimeofday)[1], 0, 4 );
  my ( $sekunde, $minute, $stunde, $tag, $monat, $jahr, $wday, $yday, $isdst ) =
    localtime(time);
  $monat++;
  my $jj = $jahr - 100;
  $jahr += 1900;

  return sprintf '%02d.%02d.%04d %02d:%02d:%02d.%04d:', $tag, $monat, $jahr,
    $stunde, $minute, $sekunde, $nano
    if ( $mode == 0 );
  return sprintf '%02d%02d%02d %02d%02d%02d%04d ', substr( $jahr, 2 ), $monat,
    $tag, $stunde, $minute, $sekunde, $nano
    if ( $mode == 1 );
  return sprintf '%02d%02d%02d%02d', substr( $jahr, 2 ), $monat, $tag, $stunde
    if ( $mode == 2 );
  return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $jahr, $monat, $tag, $stunde,
    $minute, $sekunde
    if ( $mode == 3 );
  return ( $nano, $sekunde, $minute, $stunde, $tag, $wday, $monat, $jahr )
    if ( $mode == 4 );
  return (
    sprintf( '%04d', $nano ),
    sprintf( '%02d', $sekunde ),
    sprintf( '%02d', $minute ),
    sprintf( '%02d', $stunde ),
    sprintf( '%02d', $tag ),
    $wday,
    sprintf( '%02d', $monat ),
    $jahr,
    $jj
  ) if ( $mode == 5 );
}

sub extendString {
  #################################################################
# Erweitert in einem String die Werte
#
#  $JAHR$      : Jahreszahl   4-stellig
#  $JJ$        : Jahreszahl   2-stellig
#  $MONAT$     : Monatszahl   2-stellig
#  $TAG$       : Tageszahl    2-stellig
#  $STUNDE$    : Stundenzahl  2-stellig 24h-format
#  $MINUTE$    : Minutenzahl  3-stellig
#  $SEKUNDE$   : Sekundenzahl 2-stellig
#  $TS4$       : Timestamp im Format JJJJMMTT_hhmmss
#  $TS2$       : Timestamp im Format JJMMTT_hhmmss
#
#  $PID$       : Prozess-Id
#  $PRG$       : Programmname
#  $PRGEXT$    : Programmname mit Erweiterung
#  $EXT$       : Programmnamenserweiterung
#
#  $/##$       : Char(##)
#
#  $ENV(var)$  : Umgebungsvariable var
#  $EXEC(prg)$ : Ausgabe des Programms prg
#
#  Beliebige weitere Werte koennen uebergeben werden in der Form
#  Name|Inhalt|Name|Inhalt|Name|Inhalt....
#  Bei der Referenzierung im String koennen diese benutzerdefinierten Variablen in sprintf-Manier
#  formatiert werden. Dazu ist an den Variablennamen durch % getrennt der formatstring anzuhaengen
#
#  Bsp.
#  Aufruf: extendString("MT940.$MANDANT%03s$.$TEST$.$JAHR$$MONAT$$TAG$.$STUNDE$$MINUTE$$SEKUNDE$", "MANDANT|1|TEST|234234")
#
#  Ausgabe (um 13:51:30 am 1.8.2010): MT940.001.234234.20100801.135130
#
  my $input   = shift || '';
  my $replace = shift || '';
  
  $replace = {split(/\|/, $replace)};
  
  # Ersetzen der uebergebenen Werte
  while (my ($key, $value) = each %$replace) {
    while ($input =~ /\$($key)(%[^\$]+)?\$/g) {
      if ($2) {
        $value = sprintf($2, $value);
        $input =~ s:\$$1$2\$:$value:;
      } else {
        $input =~ s:\$$1\$:$value:;
      }
    }
  }

  # Ersetzen der HEX-Werte
  $input =~ s:\$\\x([0-9A-Fa-f]{2})\$:chr hex $1:ge;

  # Ersetzen Datum, Uhrzeit, etc.
  my ( $nano, $sekunde, $minute, $stunde, $tag, $wtag, $monat, $jahr, $jj ) =
    datum(5);

  # Test, ob einer der Schluesselworte in dem String vorkommt.
  # Falls ja, Ersetzung mit dem aktuellen Wert
  $input =~ s:\$JAHR\$:$jahr:g;
  $input =~ s:\$JJ\$:$jj:g;
  $input =~ s:\$MONAT\$:$monat:g;
  $input =~ s:\$TAG\$:$tag:g;
  $input =~ s:\$STUNDE\$:$stunde:g;
  $input =~ s:\$MINUTE\$:$minute:g;
  $input =~ s:\$SEKUNDE\$:$sekunde:g;
  $input =~ s:\$TS4\$:$jahr$monat$tag\_$stunde$minute$sekunde:g;
  $input =~ s:\$TS2\$:$jj$monat$tag\_$stunde$minute$sekunde:g;


  $input =~ s:\$PID\$:$$:g;
  my ($name, $ext) = split(/\./, $Script);
  $input =~ s:\$PRG\$:$name:g;
  $input =~ s:\$PRGEXT\$:$Script:g;
  $input =~ s:\$EXT\$:$ext:g;

  $input =~ s:\$ENV\(([^\)]*?)\)\$:$ENV{$1}:g;
  $input =~ s:\$EXEC\(([^\)]*?)\)\$:`$1`:ge;

  return $input;
}

sub rel2Abs {
  ###############################################################
  #     Ermittelt den absoluten Verzeichnisnamen
  my ( $name, $mode ) = @_;

  if ( $name ne '' ) {
    $name = File::Spec->rel2abs($name);
    # Ist das Betriebssystem Windows?
    if ( $^O =~ /.*Win.*/ ) {
      $name .= '/' if ( $mode && substr( $name, -1 ) ne '/' );
    } else {
      $name .= '/' if ( $mode && -d $name && substr( $name, -1 ) ne '/' );
    }
  }
  return $name;
}

sub hmap (&$) {
  ###############################################################
  # Map-Operation auf einen Hash
  my $sub     = shift;
  my $hashref = shift;

  my %ret;

  if ( defined($hashref) ) {
    while ( my ( $key, $value ) = each %{$hashref} ) {
      local ($_) = $value;
      $ret{$key} = $sub->($value);
    }
    return \%ret;
  } else {
    return undef;
  }
}

sub deep_keys_foreach {

  #--------------------------------------------------------------
  #     Untersucht und bearbeitet rekursiv den uebergebenen Hash
  #
  # Aufruf:
  #    deep_keys_foreach(
  #      \%hash,
  #      sub {
  #        my ($key, $value) = @_;
  #        ....
  #      }
  #    );
  #
  my ( $hashref, $code, $args ) = @_;

  while ( my ( $k, $v ) = each(%$hashref) ) {
    my @newargs = defined($args) ? @$args : ();
    push( @newargs, $k );
    if ( ref($v) eq 'HASH' ) {
      deep_keys_foreach( $v, $code, \@newargs );
    } else {
      $code->(@newargs);
    }
  }
}

#################################################################
# sub getPsefData {
#     Ermitteln des Prozesstatus

sub getPsefData {
  my ( $i, @psefField );
  my ( @pids, %uid, %ppid, %ucmd );
  my $ps = 'ps -Ao user,pid,ppid,args';
  if ( "$^O" eq "darwin" ) { $ps = 'ps -Ao user,pid,ppid,command' }
  $ps .= " | @_";
  open( PSEF_PIPE, $ps );
  $i = 0;
  while (<PSEF_PIPE>) {
    chomp;
    @psefField = split( / /, $_, 4 );
    $pids[$i] = $psefField[1];
    $uid{ $pids[$i] }  = $psefField[0];
    $ppid{ $pids[$i] } = $psefField[2];
    $ucmd{ $pids[$i] } = $psefField[3];
    $i++;
  }
  close(PSEF_PIPE);
  return ( $i, \@pids, \%uid, \%ppid, \%ucmd );
}

#################################################################
# sub getSize
#     Ermittelt die Groesse einer Datei ... NOT!
#
# sub getSize
# {
#   my $file = shift;
#   my ($rc, $size1, $size2) = (-1, 0, 0);
#
#   if (sysopen(FH, $file, O_RDONLY | O_NONBLOCK)) {
#     my $size1 = (split(/ /, sysseek(FH,0,2)))[0];
#     my $size2 = (split(/ /, sysseek(FH,0,2)))[0];
#     sysseek(FH,0,0);
#     $rc = $size2 if ("$size1" ne "$size2");
#     close(FH);
#   }
#
#   return $rc;
# }

sub getSizeOfFile {
  my $file = shift;
  my @stats = stat($file) or return -1;
  return $stats[7];
}

#################################################################
# sub mk_dir
#     Ueberprueft, ob der Pfad der Datei schon existiert. Falls
#     nicht wird dieser erstellt
#
sub mk_dir {
  my $file = shift;
  
  my $rc = 0;
  my ($voldir, $dir);

  ($voldir, $dir, $file) = File::Spec->splitpath($file);
  $voldir .= $dir;

  if ($voldir !~ /[\\\/]$/) {$voldir .= '/'}
  eval {mkpath(substr($voldir, 0, length($voldir) - 1))};
  if ($@) {$rc = 1}
  
  return $rc;
}

1;
