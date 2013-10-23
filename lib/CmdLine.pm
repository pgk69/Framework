package CmdLine;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date:  $
#                       $Revision:  $
#                       $Author:  $
#
# Aufgabe:				- Kommandozeileninterpreterklasse
#
# $Id:  $
# $URL:  $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;
use open      qw(:utf8 :std);    # undeclared streams in UTF-8
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

use vars qw(@ISA $myself);
@ISA = qw();

BEGIN {
  $myself = undef;
}

#
# Module
#
use Getopt::Long qw(:config pass_through);
use FindBin qw($Bin $Script $RealBin $RealScript);

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
  my $self  = shift;
  my $class = ref($self) || $self;
  my @args  = @_;

  my $ptr = {};
  if ($myself) {
    $ptr = $myself;
    if ( $#args >= 0 ) {
      $ptr->_init(@args);
    }
  } else {
    bless $ptr, $class;
    $ptr->_init(@args);
  }

  return $ptr;
}

sub _init {
  #################################################################
  #  Initialisiert ein neues Objekt und liest die Kommandozeilen-
  #  parameter ein
  my $self = shift;
  my %args = @_;

  my %option = defined( $self->{Option} ) ? %{ $self->{Option} } : ();

  # Default Optionen, die immer vorkommen koennen
  my %getOpt = (
    'debug:i'   => \$option{Debug},
    'test:i'    => \$option{Test},
    'help|?'    => \$option{Help},
    'version'   => \$option{Version},
    'init:s'    => \$option{Configfile},
    'meldung:s' => \$option{Meldungstextefile}
  );

  # Indiviuelle Optionen
  while ( my ( $key, $value ) = each %args ) {
    $getOpt{$value} = \$option{$key} if (defined($key) && defined($value));
  }

  # Speichern der kompletten Kommandozeilenparameter
  $self->{ArgStrgRAW}  = join(' ', @ARGV);

  # Parsen der Optionen
  GetOptions(%getOpt);

  # Speichern des Optionhashs und der uebrigen Kommandozeilenparameter
  $self->{Option}   = \%option;
  $self->{Argument} = \@ARGV;
  $self->{ArgStrg}  = join(' | ', @ARGV);
  $myself           = $self;
}

sub DESTROY {
  #################################################################
  #     Zerstoert das Objekt an
  my $self = shift;
}

sub option {
  #################################################################
  # gibt eine Kommandozeilenoptionen aus bzw. setzt sie
  my $self = shift;

  my $opt = shift;
  my $val = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  if ( defined($val) ) {
    my $oldval = defined($opt) ? $self->{Option}{$opt} : undef;
    $self->{Option}{$opt} = $val;
    return $oldval;
  }

  if ( defined($opt) ) {
    return $self->{Option}{$opt};
  }

  return undef;
}

sub argument {
  #################################################################
  # gibt eine Argument aus bzw. setzt es
  my $self = shift;

  my $arg = shift;
  my $val = shift;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;
  
  my $rc = undef;
  my @ra;
  my $wantarray = wantarray();

  if ( defined($val) ) {
    my $oldval = defined($arg)
      && defined( $self->{Argument}[$arg] ) ? $self->{Argument}[$arg] : undef;
    $self->{Argument}[$arg] = $val;
    $rc = $oldval;
    $wantarray = 0;
  }

  if ( defined($arg) ) {
    if ( defined( $self->{Argument}[$arg] ) ) {
      $rc = $self->{Argument}[$arg];
      $wantarray = 0;
    }
  } else {
    foreach ( @{ $self->{Argument} } ) { push( @ra, $_ ) }
  }

  return $wantarray ? @ra : $rc;
}

sub usage {
#################################################################
  my $self = shift;
  my $version = shift || $VERSION;

  # Objekt wird nur einmal instanziiert, daher wird beim Zugriff
  # die gespeicherte Methode verwendet, falls vorhanden
  $self = $myself || $self;

  my @optionen;
  my $nummer  = -0x01000;
  while (my $zeile = Trace->new()->Meldung($nummer--, $Script)) {
    push(@optionen, $zeile);
  }
  
  my $aufruf = "\n$Script:\n";
  my $firstline = 1;
  foreach (@optionen) {
    # Entfernen der einfachen und doppelten Anfuehrungszeichen am Anfang der Option
    $_ =~ s/^['"]//;
    # Entfernen der einfachen und doppelten Anfuehrungszeichen am Ende der Option
    $_ =~ s/['"]$//;
    $aufruf .= "\n$_";
    if ($firstline) {
      $firstline = 0;
      $aufruf .= "\n";
    }
  }
  $aufruf .= "\n\nMelden Sie Fehler an <peter.kempf\@ekse.de>\n";

  my $copyright = "\nCopyright (C) 2010 EKSE Ltd. & Co. KG
Dies ist keine freie Software.
Es gibt keine Garantie; auch nicht fuer VERKAUFBARKEIT oder FUER SPEZIELLE ZWECKE.\n\n";

  $version = "\n$Script Version: " . $version . "\n\nGeschrieben von Peter Kempf\n";
  my $fehler = "\n$Script: Ungueltige Option -- " . join(" ", $self->argument()) . "\n$Script --help gibt weitere Informationen.\n";

  if ( $self->option('Help') ) {
    syswrite( STDOUT, $aufruf . $copyright );
  } elsif ( $self->option('Version') ) {
    syswrite( STDOUT, $version . $copyright );
  } else {
    syswrite( STDERR, $fehler . $copyright );
  }
}
1;
