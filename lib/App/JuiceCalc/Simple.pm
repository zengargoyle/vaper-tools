use strict;
use warnings;

package App::JuiceCalc::Simple;

use Exporter::Lite;

use App::JuiceCalc;

our @EXPORT = qw(
  name
  flav
  nic
  fill
  emitter
  list_emitters
  size
  mix
  mix_generate
  batch
  batch_generate
  batch_reset
);

{

  my ($fb, $mix, $batch);

  sub batch_reset {
    $fb = FlavorBundle->new;
    $mix = Mix->new( flavor => $fb );
    $batch = Batch->new( mix => $mix );
  }

  batch_reset();

  sub name { $fb->name( shift ) }

  sub flav { $fb->add_flavor( @_ ) }

  sub nic {
    my ($mg, $mgml, @con) = @_;
    my $f = Nicotine->new(
      mg => $mgml,
      # default PG if no carrier given
      carrier => { (pg => 1)x!@con, @con},
    );
    $mix->base( $f );
    $mix->mg( $mg );
  }

  sub fill { $mix->ratio([ @_ ]) }
  use Scalar::Util qw( looks_like_number );
  use List::AllUtils qw( first );
  #use Data::Dump;

  sub size {
    $batch->size( first { looks_like_number $_ } @_, 10 );
    #dd [ $batch ];
  }

  sub mix { $mix }

  sub mix_generate { $mix->generate }

  sub batch { $batch }

  sub batch_generate { $batch->generate }

  sub emitter { $batch->emitter( @_ ) }

  sub list_emitters { $batch->list_emitters(1) }
}
1;
