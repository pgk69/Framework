eval 'exec perl -wS $0 ${1+"$@"}'
  if 0;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date:  $
#                       $Revision:  $
#                       $Author:  $
#
# Aufgabe:        - Ausfuehrbarer Code von nmapanalyze.pl
#
# $Id:  $
# $URL:  $
#-------------------------------------------------------------------------------------------------

# Letzte Aenderung: 

use 5.010;
use strict;
use vars qw($VERSION $SVN);

use constant SVN_ID => '($Id:  $)

$Author:  $ 

$Revision:  $ 
$Date:  $ 

$URL:  $

';

# Extraktion der Versionsinfo aus der SVN Revision
($VERSION = SVN_ID) =~ s/^(.*\$Revision: )([0-9]*)(.*)$/1.0 R$2/ms;
$SVN = $VERSION . ' ' . SVN_ID;

$| = 1;

# use lib $Bin . "/lib";       # fuer Aufruf mit voll qualifiziertem Pfad noetig
use lib "./lib";    # fuer perl2exe noetig

#use lib $Bin . "/lib/SPLIT"; # fuer Aufruf mit voll qualifiziertem Pfad noetig
#use lib "./lib/SPLIT";       # fuer perl2exe noetig

#
# Module
#
use CmdLine;
use Trace;
use Configuration;
use DBAccess;

use PROGRAMM;
use PROGRAMM::Modul1;
use PROGRAMM::Modul2;

use Fcntl;
use FindBin qw($Bin $Script $RealBin $RealScript);

#
# Variablendefinition
#

#
# Objektdefinition
#

# Kommadozeilen-Objekt: Liest und speichert die Kommandozeilenparameter
$VERSION = CmdLine->new('Client'  => 'client:s',
                        'Region'  => 'region:s',
                        'Partner' => 'partner:s')->version($VERSION);

# Trace-Objekt: Liest und speichert die Meldungstexte; gibt Tracemeldungen aus
$VERSION = Trace->new()->version($VERSION);

# Config-Objekt: Liest und speichert die Initialisierungsdatei
$VERSION = Configuration->new()->version($VERSION);

# Datenbank-Objekt: Regelt dei Datenbankzugriffe
$VERSION = DBAccess->new()->version($VERSION);

# Kopie des Fehlerkanals erstellen zur gelegentlichen Abschaltung
no warnings;
sysopen(MYERR, "&STDERR", O_WRONLY);
use warnings;

#
#################################################################
## main
##################################################################
#
my $prg;
eval {$prg = PROGRAMM->new()};
if ($@) {
  Trace->Exit(0, 1, 0x0ffff, Configuration->config('Prg', 'Name'), $VERSION);
}
$VERSION = $prg->version($VERSION);
DBAccess->set_pers_Var(Configuration->config('DB', 'FID_DB').'.fid_config', 'Start');

my $a;
my %b;

$a = Configuration->config('Ausgabe', 'Log');
$a = Configuration->config('Ausgabe');
$a = Configuration->config();
$a = Configuration->config('Ausgabe', 'Frog');
$a = Configuration->config('Rausgabe', 'Frog');
$a = Configuration->config('Rausgabe');

%b = Configuration->config('Ausgabe', 'Log');
%b = Configuration->config('Ausgabe');
%b = Configuration->config();
%b = Configuration->config('Ausgabe', 'Frog');
%b = Configuration->config('Rausgabe', 'Frog');
%b = Configuration->config('Rausgabe');

  

# Test der benoetigten Kommandline-Variablen
if (CmdLine->argument(0)) {
  $prg->{Eingabemaske} = CmdLine->argument(0)
} else {
  $prg->{Eingabemaske} = Configuration->config('Eingabe', 'Fusionsliste')
}

# Anlegen der Dateien zum Log, Error-Log und Ausgabeliste sowie FMC  
Trace->Log('Log', Configuration->config('Ausgabe', 'Log')) or Trace->Exit(1, 0, 0x00010, Utils::extendString(Configuration->config('Ausgabe', 'Log')));
if (my $logrc = Trace->Log('FMC', Configuration->config('Ausgabe', 'FMC'), '0111')) {
  if ($logrc eq 'N') {
    Trace->Log('FMC', "ERSTEINTRAG") or Trace->Exit(1, 0, 0x00010, Utils::extendString(Configuration->config('Ausgabe', 'FMC')));
  }
} else {
  Trace->Exit(1, 0, 0x00010, Configuration->config('Ausgabe', 'FMC'))
}

#--------------------------------------------------------------
# PROGRAMM-Start
#--------------------------------------------------------------

DBAccess->set_pers_Var(Configuration->config('DB', 'FID_DB').'.fid_config', 'Ende '.CmdLine->new()->{ArgStrgRAW});
Trace->Exit(0, 1, 0x00002, Configuration->config('Prg', 'Name'), $VERSION);

exit 1;
