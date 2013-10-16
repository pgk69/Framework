package Trace;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date: 2013-07-31 14:09:14 +0200 (Mi, 31. Jul 2013) $
#                       $Revision: 1069 $
#                       $Author: xck90n1 $
#
# Aufgabe:				- Traceklasse
#
# $Id: Trace.pm 1069 2013-07-31 12:09:14Z xck90n1 $
# $URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/Trace.pm $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;
use open      qw(:utf8 :std);    # undeclared streams in UTF-8
use vars qw($VERSION $SVN $OVERSION);

use constant SVN_ID => '($Id: Trace.pm 1069 2013-07-31 12:09:14Z xck90n1 $)

$Author: xck90n1 $ 

$Revision: 1069 $ 
$Date: 2013-07-31 14:09:14 +0200 (Mi, 31. Jul 2013) $ 

$URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/Trace.pm $

';

# Extraktion der Versionsinfo aus der SVN Revision
($VERSION = SVN_ID) =~ s/^(.*\$Revision: )([0-9]*)(.*)$/1.0 R$2/ms;
$SVN      = $VERSION . ' ' . SVN_ID;
$OVERSION = $VERSION;

use base 'Exporter';

our @EXPORT = qw(Trc Log CloseLog TerminateLog Meldung Exit);

# our @EXPORT_OK = qw(debugLevel logConsole logFile logEvents language test);
our @EXPORT_OK = qw(debugLevel logConsole logEvents logFile language test);

use vars @EXPORT, @EXPORT_OK;

use vars qw(@ISA $myself);
@ISA = qw();

BEGIN {
  $myself = undef;
}

#
# Module
#
use CmdLine;
use Configuration;
use Utils;

use Config::IniFiles;
use Fcntl;
use FindBin qw($Bin $Script $RealBin $RealScript);
use File::Basename;
use File::Path qw(mkpath);
use FileHandle;

#
# Klassenvariablen
#

#
# Methoden
#
sub version {
  my $self     = shift();
  my $pversion = shift();

  $OVERSION =~ m/^([^\s]*)\sR([0-9]*)$/;
  my ($oVer, $oRel) = ($1, $2);
  
  if (defined($pversion)) {
    $pversion =~ m/^([^\s]*)\sR([0-9]*)$/;
    my ($pVer, $pRel) = ($1, $2);
    $VERSION = $oRel > $pRel ? "$pVer R$oRel" : "$pVer R$pRel";
  }

  return wantarray() ? ( $VERSION, $OVERSION ) : $VERSION;
}

sub new {
  #################################################################
  #     Legt ein neues Objekt an falls noch keines existiert
  if ($myself) { return $myself }

  my $self  = shift;
  my $class = ref($self) || $self;
  my @args  = @_;

  my $ptr = {};
  bless $ptr, $class;

  $ptr->_init(@args);

  return $ptr;
}

sub _init {
  #################################################################
  #     Initialisiert ein neues Objekt
  my $self = shift;
  my @args = @_;

  # Variablen mit Defaults belegen
  #
  # intern
  $self->{MeldungstexteFile} =
    $Bin . '/' . ( split( /\./, $Script ) )[0] . '.txt';

  # variabel
  $self->debugLevel(0);
  $self->logEvents('');

  $self->logConsole('1');
  $self->language('default');

  # jetzt ist das Objekt ok und muss zur Vermeidung von Loops
  # erstmal gesichert werden
  $myself = $self;

  # Ueberschreiben der Werte fuer Debug und Testmode mit 
  # Parameter aus der Kommandozeile
  CmdLine->new();

  # Ueberschreiben der Konfigurationswerte mit 
  # Parameter aus dem Konfigfile
  Configuration->new();

  if ( my $dummy = CmdLine->option('Meldungstextefile') ) {
    $self->{MeldungstexteFile} = $dummy;
  }
  $self->debugLevel(CmdLine->option('Debug'));
  $self->test(CmdLine->option('Test'));

  # Objekt erneut sichern
  $myself = $self;

  # Ueberschreiben der Werte mit Parameter aus dem Configfile
  # my $configuration = Configuration->new();

  my $dummy;
  $dummy = Configuration->config('Logging', 'Debug') || Configuration->config('Debug', 'Level');
  if (!defined(CmdLine->option('Debug')) && defined($dummy)) {
    $self->debugLevel($dummy);
  }
  $dummy = Configuration->config('Logging', 'LogEvents') || Configuration->config('Debug', 'Events');
  if (defined($dummy)) {$self->logEvents($dummy)}
  if (!defined(CmdLine->option('Test')) && defined($dummy = Configuration->config('Prg', 'Testmode'))) {
    $self->test($dummy);
  }

  if (!exists($self->{Log}{$Script}{Template})) {
    my ($lgFile, $lgConsole, $lgClose) = split(/\|/, Configuration->config('Logging', 'LogFile') || Configuration->config('Debug', 'File'));
    $lgConsole = $lgConsole || Configuration->config('Logging', 'LogConsole') || Configuration->config('Debug', 'Console');
    $self->Trc( '*', 'NEW' . $Script, $lgFile, $lgConsole || 0, $lgClose || 0, '0002' );
  }

  # Objekt erneut sichern
  $myself = $self;
}

sub DESTROY {
  #################################################################
  #     Zerstoert das Objekt an
  my $self = shift;

  foreach (keys(%{$self->{Log}})) {
    if ((ref($self->{Log}{$_}) eq "HASH") && defined($self->{Log}{$_}{Handle})) {
      $self->{Log}{$_}{Handle}->close if (defined $self->{Log}{$_}{Handle});
    }
  }
}

sub Trc {
  #################################################################
  #     Traceausgabe
  # Aufruf: "*" "" "Tracedateiname" "Parameter"
  # Level = 'NEW'|'LOG' . Log-Name : Logdatei anlegen
  #         Anlegen einer neue Logdatei
  # Rueckgabewert: 1 - das Logfile existierte bereits, es wird 
  #                    angehaengt
  #                N - das Logfile wurde neu angelegt
  #                0 - das Logfile konnte nicht angelegt oder geoeffnet werden
  #
  # Programmtrace
  # Level >= 0 : Traces, die in die Programmtracedatei
  #              geschrieben werden
  # Aufruf: "EventKlasse" "Level" "String" "Parameter"
  #
  # Programmlogging
  # Level < 0  : Benutzerdefinierte Logdatei anlegen
  # Aufruf: "L" "Logdateinummer" "Logstring" "Parameter"
  #         Schreibt den Logstring erweitert um Parameter
  #         in die Logdatei
  # Rueckgabewert: 0 - das Logfile existierte bereits, es wird 
  #                    angehaengt
  #                1 - das Logfile wurde neu angelegt
  #
  my $self = shift;
                                        # Log schreiben                 Log anlegen
  my $event  = shift || '';             # Event                         '*'
  my $level  = shift || 0;              # Level                         'NEW'|'LOG' . Log-Name
  my $trcStr = shift || '';             # Logstring bzw. LogstringID    Log-Dateiname
  my @trcParam = $#_ >= 0 ? @_ : ('');  # Logparameter                  Log auf Console|Close Logfile|umask

  # Default: ok
  my $rc = 1;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $mylevel = defined($level) && $level !~ /\D/ ? $level : 0;

  # Test, ob der aktuelle Event in der Liste der Events auftaucht
  if (
    ($self->{Debug} >= $mylevel)
    && (!$self->{Log}{Events}
      || ($event eq '*')
      || ($event ne '' && $self->{Log}{Events} =~ /[$event]/))
    )
  {
    my $logName = $Script;
    # Beginnt der Level mit NEW oder LOG?
    if ($level =~ '^NEW|LOG') {
      $logName = substr($level, 3);
      # Beginnt der Level mit NEW
      if ($level =~ '^NEW') {
        $self->{Log}{$logName}{Template}         = $trcStr;
        $self->{Log}{$logName}{Console}          = $trcParam[0];
        $self->{Log}{$logName}{CloseAfterWrite}  = $trcParam[1];
        $self->{Log}{$logName}{uMask}            = $trcParam[2];
      }
    }
    
    $trcStr = $self->Meldung($trcStr, @trcParam);

    # Trace in die Datei
    if (my $curLogFile = extendString($self->{Log}{$logName}{Template})) {
      if (!defined($self->{Log}{$logName}{Handle}) || !defined($self->{Log}{$logName}{File}) || ("$self->{Log}{$logName}{File}" ne "$curLogFile")) {
        $self->{Log}{$logName}{File} = $curLogFile;
        $self->{Log}{$logName}{Handle}->close() if (defined $self->{Log}{$logName}{Handle});
        umask 0002;
        if (!-e dirname($curLogFile)) {
          File::Path::mkpath(dirname($curLogFile), {error => \my $err});
          if (@$err) {
            my $diag = $$err[0];
            my ($file, $message) = %$diag;
            $trcStr = "Error creating LogFile Directory ".dirname($curLogFile).": $message";
            if ($logName != $Script) {$self->Trc('I', 0, $trcStr)}
            else                     {$level = ''}
          }
        }

        #$log->open("$self->{LogFile}", O_WRONLY | O_APPEND | O_CREAT | O_NONBLOCK);
        $self->{Log}{$logName}{Handle} = IO::File->new();
        $rc = 'N' if (! -e $curLogFile);
        if (defined($self->{Log}{$logName}{Handle})) {
          $self->{Log}{$logName}{Handle}->autoflush;
          if (!$self->{Log}{$logName}{CloseAfterWrite}) {
            umask $self->{Log}{$logName}{uMask};
            # $self->{Log}{$logName}{Handle}->open( '>>' . $curLogFile ) || $self->Exit(1, 0, 'Unable to open file for ' . $curLogFile);
            $self->{Log}{$logName}{Handle}->open( '>>' . $curLogFile ) or $rc = 0;
            umask 0002;
          }
        } else {
          # $self->Exit(1, 0, 'Unable to open filehandle for ' . $curLogFile)
          $rc = 0;
        }
      }
      if ($level !~ '^NEW') {
        my $myTrcStr = $trcStr;
        if ($logName eq $Script) {
          $myTrcStr = datum(0) . " $$ " . $myTrcStr;
        }
        if (defined($self->{Log}{$logName}{Handle})) {
          if ($self->{Log}{$logName}{CloseAfterWrite}) {
            umask $self->{Log}{$logName}{uMask};
            # $self->{Log}{$logName}{Handle}->open( '>>' . $curLogFile ) || $self->Exit(1, 0, 'Unable to open file for ' . $curLogFile);
            if ($self->{Log}{$logName}{Handle}->open('>>' . $curLogFile)) {
              umask 0002;
              $self->{Log}{$logName}{Handle}->print($myTrcStr . "\n");
              $self->{Log}{$logName}{Handle}->close if (defined $self->{Log}{$logName}{Handle});
            } else {$rc = 0;}
          } else {
            $self->{Log}{$logName}{Handle}->print($myTrcStr . "\n");
          }
        }
      }
      # Falls wir an der Ausgabe interessiert sind, wird sie hochgereicht und das PRogramm muss 
      # selbst auf den Fehler reagieren
      # Falls wir nicht interessiert sind, brechen wir im Fehlerfall selbstaendig ab
      if (!$rc && !defined(wantarray())) {
        $self->Exit(1, 0, 'Unable to write logfile ' . $curLogFile);
      }
    }

    # Tracen auf die Konsole
    if ($self->{Log}{$logName}{Console} && $level !~ '^NEW') {
      my ($subroutine, $i) = ('', 0);
      while (defined(caller(++$i))) {
        $subroutine .= (caller($i))[3] . '(' . (caller($i - 1))[2] . '):';
      }

      if ($subroutine) {
        syswrite(STDOUT, datum(0) . " $$ $Script $subroutine " . $trcStr . "\n");
      } else {
        syswrite(STDOUT, datum(0) . " $$ $Script \(".(caller(0))[2]."\): " . $trcStr . "\n");
      }
    }
  }

  return $rc;
}

sub Exit {
  ###############################################################
  #     Programm beenden
  # Parameter: $1 Returncode
  #            $2 Debuglevel
  #            $3ff Traceargumente
  my ($self, $rc, $dbg) = (shift, shift || 0, shift || 0);
  my @log = @_;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $rcstr = '';
  if ($rc > 1) {
    $rcstr = sprintf("0x%03x ", $rc);
    chomp(@log);
    foreach (@log) {$rcstr .= $_}
    $self->Trc('S', $dbg, $rcstr);
  } else {
    $self->Trc('S', $dbg, @log);
  }

  if (!$rc) {
    $@ = ();
    $! = 0;
  };
  exit $rc;
}

sub Log {
  ###############################################################
  #     Meldung in ein Logfile ausgeben
  # Parameter: $1 Logname
  #            $2 Meldungsnummer oder -text
  #            $3ff Traceargumente
  #
  # Wenn nur ein Parameter angegeben wird, wird ein Logfile
  # mit dem angegebenen Namen angelegt.
  # Rueckgabewert: 1 - das Logfile existierte bereits, es wird 
  #                    angehaengt
  #                N - das Logfile wurde neu angelegt
  #                0 - das Logfile konnte nicht angelegt oder geoeffnet werden
  my $self = shift;
                                        # Log schreiben                 Log anlegen
  my $log      = shift || '';           # Name des Logs                 Name des Logs
  my $logStr   = shift || 0;            # Logstring bzw. LogstringID    Log-Dateiname|Log auf Console|Close Logfile
  my @logParam = $#_ >= 0 ? @_ : ('');  # Logparameter                  umask (Default 0002)

  my $rc;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  if ( exists( $self->{Log}{$log} ) ) {
#    if (defined(wantarray())) {
#      $rc = $self->Trc( 'L', 'LOG' . $log, $logStr, @logParam );
#    } else {
#      $self->Trc( 'L', 'LOG' . $log, $logStr, @logParam );
#    }
    if (defined(wantarray())) {
      $rc = $self->Trc( '*', 'LOG' . $log, $logStr, @logParam );
    } else {
      $self->Trc( '*', 'LOG' . $log, $logStr, @logParam );
    }
  } else {
    my ( $lgFile, $lgConsole, $lgClose ) = split( /\|/, $logStr );
    if (defined(wantarray())) {
      $rc = $self->Trc( '*', 'NEW' . $log, $lgFile, $lgConsole || 0, $lgClose || 0, $logParam[0] || '0002' );
    } else {
      $self->Trc( '*', 'NEW' . $log, $lgFile, $lgConsole || 0, $lgClose || 0, $logParam[0] || '0002' );
    }
  }
  return $rc;
}

sub CloseLog {
  ###############################################################
  #     Logfile schliessen
  # Parameter: $1 Logname
  #
  # LogFile wird geschlossen um es weiter zu bearbeiten (Bsp.
  # Mailversand). Das Objekt bleibt aber erhalten. Bei erneuter
  # Verwendung wird das File automatisch wieder geoeffnet.
  my $self = shift;

  my $log  = shift || '';
 
  # Default: not ok 
  my $rc = 0;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  if (exists($self->{Log}{$log})) {
  	if (defined $self->{Log}{$log}{Handle}) {
      $self->{Log}{$log}{Handle}->close;
      delete($self->{Log}{$log}{Handle});
  	}
    $rc = 1;
  }
  return $rc;
}

sub TerminateLog {
  ###############################################################
  #     Logfile beenden
  # Parameter: $1 Logname
  #
  # LogFile wird geschlossen und vergessen.
  # Vor einer erneuten Verwendung muss das Logfile manuell neu
  # geoeffnet werden mit dem Aufruf log(<Name>, <Dateiname>)
  my $self = shift;

  my $log  = shift || '';
 
  # Default: not ok 
  my $rc = 0;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  if (exists($self->{Log}{$log})) {
    $self->{Log}{$log}{Handle}->close if (defined $self->{Log}{$log}{Handle});
    delete($self->{Log}{$log});
    $rc = 1;
  }
  return $rc;
}

sub Meldung {
  ###############################################################
  #     Liest die Meldungsdatei ein
  # Definition der Errorcodes und Meldungstexte
  # ----------------------------------------
  # Errorcode 0x0?###: Allgemeine
  # Errorcode 0x1?###: Client
  # Errorcode 0x2?###: Server
  # ----------------------------------------
  # Errorcode 0x?0###-0x?E###: Log-/Trc-Ausgaben
  # Errorcode 0x?E###-0x?E###: Warnungen
  # Errorcode 0x?F###-0x?F###: Abbrueche
  # ----------------------------------------
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $id = shift();
  my @param = $#_ >= 0 ? @_ : ('');

  my $wantrc = 0;

  # Falls $self->{Meldung}{'0x00000'} nicht definiert ist wird erst einmal geladen
  if ( !defined($id) || !exists( $self->{Meldung}{'0x00000'} ) ) {
    if ( -r $self->{MeldungstexteFile} ) {
      untie( my %meldung );
      tie( %meldung, 'Config::IniFiles',
        ( -file => $self->{MeldungstexteFile} ) )
        || $self->Exit( 1, 0,
        'Language Messagefile not accessable: ' . $self->{MeldungstexteFile} );
      $self->{Meldung} = $meldung{ $self->{Lang} };
    }

    # Check auf doppelte Eintraege im Messagefile. Diese fuehren zu Problemen
    while ( my ( $k, $v ) = each( %{ $self->{Meldung} } ) ) {
      if ( my $r = ref( $self->{Meldung}{$k} ) ) {
        $self->Exit( 1, 0,
"Failure: <$r> in the messagefile in language section <$self->{Lang}> for variable <$k> defined."
        );
      }
    }
    $self->{Meldung}{'0x00000'} =
      'Undefined Errorcode: %s %s %s %s %s %s %s %s %s %s'
      if ( !exists( $self->{Meldung}{'0x00000'} ) );
  }

  my $hexId = undef;
  if ( defined($id) ) {
    if ( substr( $id, 0, 1 ) eq '-' ) {
      $wantrc = 1;
      $id = substr( $id, 1 );
    }
    # Test, ob die id eine Hex-Zahl ist
    $hexId =
        $id =~ /^[0-9]+$/ ? sprintf( "%#07x", $id )
      : $id =~ /^0x[0-9a-f]{5}$/ ? $id
      :                            undef;
  }

  no warnings "all";
  if ( defined($hexId) ) {
    if ( exists( $self->{Meldung}{$hexId} ) ) {
      $id = sprintf( $self->{Meldung}{$hexId}, @param );
    } else {
      $id = $wantrc ? 0 : sprintf( $self->{Meldung}{'0x00000'}, $hexId );
    }
  } else {
    $id = sprintf( $id, @param );
  }
  chomp($id);
  use warnings "all";

  return extendString($id);
}

sub _GetSetVar {
  ###############################################################
  #     Aendert eine Variable und gibt den alten Wert zurueck
  my $self = shift();

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $var      = shift();
  my $proc     = shift();
  my $newValue = shift();

  my $value = $self->{$var};
  if ( defined($newValue) ) {
    $self->{$var} = $newValue;
    $self->$proc() if ($proc);
  }

  return $value;
}

sub debugLevel {    #     gibt den Debuglevel aus, bzw setzt ihn
  return _GetSetVar( shift, 'Debug', '', @_ );
}

sub logEvents {     #     gibt die LogEvents aus, bzw setzt sie
  my $self = shift();

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $newValue = shift();

  my $value = $self->{Log}{Events};
  if ( defined($newValue) ) {
    $self->{Log}{Events} = $newValue;
  }

  return $value;
}

sub logConsole {    #     gibt die Option 'Log auf Konsole' aus, bzw setzt sie
                    # return _GetSetVar( shift, 'LogConsole', '', @_ );
  my $self = shift();

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  $self->{Log}{$Script}{Console} = $self->{Log}{$Script}{Console} ? 0 : 1;
  return !$self->{Log}{$Script}{Console};
}

sub logFile {     #     gibt den LogFilenamen aus
  my $self = shift();

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $log = shift() || '';

  my $value = exists($self->{Log}{$log}) ? $self->{Log}{$log}{File} : undef;

  return $value;
}

sub language {      #     gibt den Sprache aus, bzw setzt sie
  return _GetSetVar( shift, 'Lang', 'Meldung', @_ );
}

sub test {          #     gibt den Modus aus, bzw. setzt ihn
  return _GetSetVar( shift, 'Testmode', '', @_ );
}

1;
