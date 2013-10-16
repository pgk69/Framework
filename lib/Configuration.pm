package Configuration;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date: 2013-07-31 14:09:14 +0200 (Mi, 31. Jul 2013) $
#                       $Revision: 1069 $
#                       $Author: xck90n1 $
#
# Aufgabe:				- Konfigurationsklasse
#
# $Id: Configuration.pm 1069 2013-07-31 12:09:14Z xck90n1 $
# $URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/Configuration.pm $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;
use open      qw(:utf8 :std);    # undeclared streams in UTF-8
use vars qw($VERSION $SVN $OVERSION);

use constant SVN_ID => '($Id: Configuration.pm 1069 2013-07-31 12:09:14Z xck90n1 $)

$Author: xck90n1 $ 

$Revision: 1069 $ 
$Date: 2013-07-31 14:09:14 +0200 (Mi, 31. Jul 2013) $ 

$URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/Configuration.pm $

';

# Extraktion der Versionsinfo aus der SVN Revision
( $VERSION = SVN_ID ) =~ s/^(.*\$Revision: )([0-9]*)(.*)$/1.0 R$2/ms;
$SVN = $VERSION . ' ' . SVN_ID;
$OVERSION = $VERSION;

use base 'Exporter';

our @EXPORT    = qw(config);
our @EXPORT_OK = qw(host);

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

use FindBin qw($Bin $Script $RealBin $RealScript);
use Sys::Hostname;

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
  #     Initialisiert ein neues Objekt
  my $self = shift;
  my @args = @_;

  # Variablen
  #
  my %conf;

  # Variablen mit Defaults belegen
  #
  $self->host( uc(hostname) );
  $self->{Configfile} = $Bin . '/' . ( split( /\./, $Script ) )[0] . '.ini';

  # jetzt ist das Objekt ok und muss zur Vermeidung von Loops
  # erstmal gesichert werden
  $myself = $self;

  # Ueberschreiben der Konfigurationswerte mit Parameter aus der Kommandozeile
  CmdLine->new();
  if ( CmdLine->option('Configfile') ) {
    $self->{Configfile} = CmdLine->option('Configfile');
  }

  # Objekt erneut sichern
  $myself = $self;
  # Ueberschreiben der Konfigurationswerte mit Parameter aus der Konfigurationsfile
  Trace->new();

  if ( !-r $self->{Configfile}
    || !tie( %conf, 'Config::IniFiles', ( -file => $self->{Configfile} ) ) )
  {
    Trace->Exit( 1, 0, 0x08400, $self->{Configfile} );
  }
  $self->{Config} = \%conf;

  # Objekt erneut sichern
  $myself = $self;

  # Check auf doppelte Eintraege im Messagefile. Diese fuehren zu Problemen
  while ( my ( $k, $v ) = each(%conf) ) {
    my %chash = %{ $conf{$k} };
    while ( my ( $mk, $mv ) = each(%chash) ) {
      if ( my $r = ref($mv) ) {
        my $val     = $conf{Logging}{LogEvents} || $conf{Debug}{Events};
        my $hostval = $conf{'Logging.' . $self->{Host}}{LogEvents} || $conf{'Debug.' . $self->{Host}}{Events};
        if ( my $rs = defined($hostval) ? $hostval : defined($val) ? $val : undef ) {
          if (index(uc($rs), 'W') >= 0) {
            Trace->Exit( 1, 0, 0x08401, $r, $k, $mk );
          } else {
            Trace->Trc( 'C', 0, 0x08401, $r, $k, $mk );
          }
        }
      }
    }
  }

  # Set Language
  if (defined(my $dummy = $self->config('Prg', 'Language'))) {
    Trace->language($dummy);
  }

  # Set Testmode
  if ( !defined( CmdLine->option('Test') )
    && defined( my $dummy = $self->config( 'Prg', 'Testmode' ) ) ) {
    Trace->test($dummy);
  }

  # Objekt erneut sichern
  $myself = $self;
}

sub DESTROY {
  #################################################################
  #     Zerstoert das Objekt
  my $self = shift;
}

sub config {
  ###############################################################
  #     Liest die Initialisierungsdatei ein
  my $self   = shift;
  my @action = @_;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my $wantarray = wantarray();
  my ($value, %valuehash);
  
  if (exists($action[0])) {
  	my $hostval = defined($self->{Config}{$action[0] . '.' . $self->{Host}}) ? $self->{Config}{$action[0] . '.' . $self->{Host}} : undef;
    my $globval = defined($self->{Config}{$action[0]}) ? $self->{Config}{$action[0]} : undef;
    if (exists($action[1])) {
      $value = defined($hostval) && defined($$hostval{$action[1]}) ? $$hostval{$action[1]} : undef;
      if (!defined($value)) {
        $value = defined($globval) && defined($$globval{$action[1]}) ? $$globval{$action[1]} : undef;
      }
    } else {
      $value = defined($hostval) ? $hostval : $globval;
    }
  } else {
    $value = $self->{Config};
  }
  
  if (defined($value) && $wantarray) {
  	if (ref($value) ne 'HASH') {
  	  $wantarray = 0;
  	} else {
      foreach (keys(%$value)) {$valuehash{$_} = $$value{$_}}
    }
  }
  
  return $wantarray ? %valuehash : $value;
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

sub host {
  return _GetSetVar( shift, 'Host', '', @_ );
}    #     gibt den Hostnamen aus, bzw. setzt ihn zu Testzwecken

sub prg {           #     gibt den Programmnamen aus
  my $self = shift();
 
  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  return $self->config('Prg', 'Name') || $Script;
}

1;
