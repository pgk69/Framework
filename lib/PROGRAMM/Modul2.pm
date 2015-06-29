package Modul2;

#-------------------------------------------------------------------------------------------------
# Letzte Aenderung:     $Date: 2012-10-18 09:19:15 +0200 (Do, 18 Okt 2012) $
#						$Revision: 910 $
#                       $Author: xck90n1 $
#
# Aufgabe:				- Ausfuehrbarer Code von DTAUS.pm
#
# $Id: Modul2.pm 910 2012-10-18 07:19:15Z xck90n1 $
# $URL: https://svn.fiducia.de/svn/multicom/trunk/multicom/Framework_OO/lib/PROGRAMM/Modul2.pm $
#-------------------------------------------------------------------------------------------------

use 5.004;
use strict;

use base 'Exporter';

our @EXPORT    = ();
our @EXPORT_OK = ();

use vars @EXPORT, @EXPORT_OK;

use vars qw( @ISA );
@ISA = qw(SPLIT);

#
# Module
#

#
# Konstantendefinition
#

#
# Variablendefinition
#

#
# Methodendefinition
#

sub mache_was {
  #################################################################
  #     Was machen
  my $self = shift;
  $self->{subroutine} = ( caller(0) )[3];

  $self->Trc( 'S', 1, 0x00001, $self->{subroutine} );
  my $rc = 1;


  $self->Trc( 'S', 1, 0x00002, $self->{subroutine} );
  $self->{subroutine} = '';

  # Explizite Uebergabe des Returncodes noetig, da sonst ein Fehler auftritt
  return $rc;
}
1;
