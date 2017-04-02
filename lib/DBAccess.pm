package DBAccess;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date:  $
#                       $Revision:  $
#                       $Author:  $
#
# Aufgabe:				- Datenbankzugriffsklasse
#
# $Id:  $
# $URL:  $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;
use vars qw($VERSION $SVN $OVERSION);

use constant SVN_ID => '($Id:  $)

$Author:  $ 

$Revision:  $ 
$Date:  $ 

$URL:  $

';

# Extraktion der Versionsinfo aus der SVN Revision
( $VERSION = SVN_ID ) =~ s/^(.*\$Revision: )([0-9]*)(.*)$/1.0 R$2/ms;
$SVN = $VERSION . ' ' . SVN_ID;
$OVERSION = $VERSION;

use base 'Exporter';

our @EXPORT    = qw(option argument);
our @EXPORT_OK = ();

use vars @EXPORT, @EXPORT_OK;

use vars qw(@ISA $myself $idx);
@ISA = qw();

BEGIN {
  $myself = undef;
  $idx = 0;
}

#
# Module
#
use Getopt::Long qw(:config pass_through);
use FindBin qw($Bin $Script $RealBin $RealScript);
use Date::Format;

#
# Klassenvariablen
#

my @DB_RW_Mode;
# 0 : Lesen
# 1 : Schreiben, Loeschen

#
# Methoden
#
sub version {
  my $self     = shift();
  my $pversion = shift();

  $OVERSION =~ m/^([^\s]*)\sR([0-9]*)$/;
  my ($oVer, $oRel) = ($1, $2);
  $oVer = 0 if (!$oVer);
  $oRel = 0 if (!$oRel);

  if (defined($pversion)) {
    $pversion =~ m/^([^\s]*)\sR([0-9]*)$/;
    my ($pVer, $pRel) = ($1, $2);
    $pVer = 0 if (!$pVer);
    $pRel = 0 if (!$pRel);
    $VERSION = $oRel gt $pRel ? "$pVer R$oRel" : "$pVer R$pRel";
  }

  return wantarray() ? ($VERSION, $OVERSION) : $VERSION;
}

sub new {
  #################################################################
  #     Legt ein neues Objekt an
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
  #  Initialisiert ein neues Objekt und liest die Kommandozeilen-
  #  parameter ein
  my $self = shift;
  my %args = @_;

  # jetzt ist das Objekt ok und muss zur Vermeidung von Loops
  # erstmal gesichert werden
  $myself           = $self;

  # Ueberschreiben der Werte mit Parameter aus der Kommandozeile
  #my $cmdline = CmdLine->new();

  # Ueberschreiben der Werte mit Parameter aus dem Configfile
  #my $configuration = Configuration->new();

  # Ueberschreiben der Konfigurationswerte mit Parameter aus der Konfigurationsfile
  #my $trace = Trace->new();

  # Zugriff auf die Datenbank
  use DBI;

  if (Configuration->config('DB', 'RDBMS')) {
    my $dbms = 'DBD/' . Configuration->config('DB', 'RDBMS') . '.pm';
    my $dbh;

    if (Trace->test() < 2) { 
      eval {
        require $dbms;
        $dbms->import();
      };
      if ($@) {Trace->Exit(1, 0, 0x08001, $dbms)}

      my $data_source = 'dbi:' . Configuration->config('DB', 'RDBMS') . ':' . Configuration->config('DB', 'DBNAME');

      eval {
        $dbh = DBI->connect(
          $data_source,
          Utils::extendString(Configuration->config('DB', 'USER')),
          Utils::extendString(Configuration->config('DB', 'PASSWD')),
          { AutoCommit => 0, RaiseError => 0, PrintError => 0 }
        );
      };
      if ($@ || !defined($dbh)) {Trace->Exit(1, 0, 0x08500, $data_source, $DBI::errstr)}
    }
    $self->{dbh} = $dbh;

    $self->{AutoCommit} = Configuration->config('DB', 'AUTOCOMMIT') || 0;
    Trace->Trc('D', 5, 'Set Autocommit to ' . $self->{AutoCommit});
  
    # Objekt erneut sichern
    $myself = $self;
  }
}

sub DESTROY {
  #################################################################
  #     Zerstoert das Objekt an
  my $self = shift;

  # Transaktion zurueckrollen, falls noetig
  $self->{dbh}->rollback()   if (defined($self->{dbh}));
  # $self->{sth}->finish()     if (defined($self->{sth}));
  $self->{dbh}->disconnect() if (defined($self->{dbh}));
}

sub autocommit {
  #################################################################
  #     Ggf. Zyklisches Absetzen des Commits
  #     Falls der Schalter AutoCommit im INI-File gesetzt ist, wird
  #     nach AutoCommit Aufrufen der Prozedur ein Commit abgesetzt. 
  #

  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if ($self->{AutoCommit} > 0) {
      $self->{AutoCommit}--;
      if ($self->{AutoCommit} <= 0) {
        $self->{AutoCommit} = Configuration->config('DB', 'AUTOCOMMIT') || 0;
        Trace->Trc('D', 5, 'Executing Autocommit - commit');
        DBAccess->commit() or Trace->Exit(0x104, 0, "Error: $DBI::errstr");
      } else {
        Trace->Trc('D', 5, 'Executing Autocommit - no commit counter: ' . $self->{AutoCommit});
      }
    } else {
      Trace->Trc('D', 5, 'Executing Autocommit - no autocommit set');
    }
  }

  # Explizite Uebergabe des Returncodes noetig, da sonst ein Fehler auftritt
  return $rc;
}

sub prepare {
  #################################################################
  # bereitet ein DB-Statement vor
  my $self = shift;
  my $stmt = shift;
  $idx  = shift || $idx || 0;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if (Trace->test() <= 1) {
      $rc = ($self->{sth}[$idx] = $self->{dbh}->prepare($stmt));
    }

    $DB_RW_Mode[$idx] = -1; # 0 : Read   1 : Write/Delete
    if (uc($stmt) =~ /^SELECT /) {$DB_RW_Mode[$idx] = 0}
    if (uc($stmt) =~ /^(UPDATE |INSERT |DELETE )/) {$DB_RW_Mode[$idx] = 1}
  }
  
  return $rc;
}

sub setidx {
  #################################################################
  # setzt den Indexes
  my $self = shift;
  $idx  = shift || 0;
}

sub getidx {
  #################################################################
  # setzt den Indexes
  my $self = shift;
  return $idx;
}

sub getnextidx {
  #################################################################
  # ermittelt den naechsten freien Index
  my $self = shift;
  
  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $nextidx = 0;
  
  while (defined($self->{sth}[$nextidx])) {$nextidx++}
  
  return $nextidx;
}

sub getseq {
  #################################################################
  # holt die naechste Sequenz Nummer
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = -1;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = ($self->{sth}[$idx]->{mysql_insertid});
    }
  }

  return $rc;
}

sub execute {
  #################################################################
  # fuehrt ein DB-Statement aus
  my $self = shift;

  my @parameter = @_;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = ($self->{sth}[$idx]->execute(@parameter));
    }
  }

  return $rc;
}

sub bind_columns {
  #################################################################
  # fuehrt ein DB-Statement aus
  my $self = shift;

  my $fieldhashptr      = shift;
  my $fieldnamearrayptr = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = ($self->{sth}[$idx]->bind_columns(map {\$$fieldhashptr{$_}} @{$fieldnamearrayptr}));
    }
  }

  return $rc;
}

sub fetch {
  #################################################################
  # holt einen Datensatz als Array
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = undef;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = $self->{sth}[$idx]->fetch();
    }
  }

  return $rc;
}

sub fetchrow_array {
  #################################################################
  # holt einen Datensatz als Array
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = undef;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = $self->{sth}[$idx]->fetchrow_array();
    }
  }

  return $rc;
}

sub fetchrow_hashref {
  #################################################################
  # holt einen Datensatz als Hash
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = undef;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = $self->{sth}[$idx]->fetchrow_hashref();
    }
  }

  return $rc;
}

sub finish {
  #################################################################
  # beendet ein DB-Statement aus
  my $self  = shift;
  my $forget = shift || 0;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = ($self->{sth}[$idx]->finish());
      if ($forget) {delete($self->{sth}[$idx])}
    }
  }

  return $rc;
}

sub commit {
  #################################################################
  # schliesst ein DB-Transaktion
  my $self = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = 1;
  
  if (%{$self}) {
    if (Trace->test() + $DB_RW_Mode[$idx] <= 1) {
      $rc = ($self->{dbh}->commit());
    }
  }

  return $rc;
}

sub set_pers_Var {
  ###############################################################
  # Setzt eine persistente Variable
  #
  # Eingabe Variablenname und Variableninhalt
  my $self       = shift;
  my $table      = shift || undef;
  my $varname    = shift || undef;
  my $varcontent = shift || time2str('%Y-%m-%d-%H.%M.%S', time());
  my $substitute = shift || undef;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  if (%{$self}) {
    if (defined($varname) && defined($varcontent) && !Trace->test()) {
      # Falls substitute mitgegeben wurde, wird der alte Eintrag (z.B.: Start% oder Ende% geloescht)
      if (defined($substitute)) {
        $self->prepare('DELETE FROM '.$table.' WHERE programm = ? AND varname LIKE ?') or Trace->Exit(0x11e, 0, "Error: $DBI::errstr");
        $self->execute(Configuration->prg, $substitute) or Trace->Exit(0x11f, 0, "Error: $DBI::errstr");
      }
      $self->prepare('INSERT INTO '.$table.' VALUES (?, ?, ?, ?)')
        or Trace->Exit(0x11d, 0, "Error: $DBI::errstr");
      if (!$self->execute(time2str('%Y-%m-%d-%H.%M.%S', time()), Configuration->prg, $varname, $varcontent)) {
        $self->prepare('UPDATE '.$table.' SET aktualisiert = ?, varcontent = ? WHERE programm = ? AND varname = ?')
          or Trace->Exit(0x11e, 0, "Error: $DBI::errstr");
        $self->execute(time2str('%Y-%m-%d-%H.%M.%S', time()), $varcontent, Configuration->prg, $varname)
          or Trace->Exit(0x11f, 0, "Error: $DBI::errstr");
      }
      $self->finish() or Trace->Exit(0x120, 0, "Error: $DBI::errstr");
      $self->commit() or Trace->Exit(0x121, 0, "Error: $DBI::errstr");
    }
  }
}

sub get_pers_Var {
  ###############################################################
  # Ermittelt eine persistente Variable
  #
  # Eingabe: Variablenname, [Defaultwert]
  #
  # Ausgabe: Variableninhalt oder 'undef', falls die Variable
  #          nicht vorhanden ist
  my $self    = shift;
  my $table   = shift || undef;
  my $varname = shift || undef;
  my $result  = shift || undef;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $myresult;

  if (%{$self}) {
    if (defined($varname) && (Trace->test() <= 1)) {
      $self->prepare('SELECT varcontent FROM '.$table.' WHERE programm = ? AND varname = ? WITH UR')
        or Trace->Exit(0x11a, 0, "Error: $DBI::errstr");
      $self->execute(Configuration->prg, $varname)
        or Trace->Exit(0x11b, 0, "Error: $DBI::errstr");
      if (($myresult) = $self->fetchrow_array()) {$result = $myresult}
      $self->finish() or Trace->Exit(0x11c, 0, "Error: $DBI::errstr");
    }
  }

  return $result;
}

1;
