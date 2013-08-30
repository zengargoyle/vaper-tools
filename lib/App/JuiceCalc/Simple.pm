use strict;
use warnings;

package App::JuiceCalc::Simple;
use Exporter::Lite;

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
  amt
  amt_reset
  amt_generate
);

use List::AllUtils qw( sum first );
use Scalar::Util qw( looks_like_number );

use App::JuiceCalc;

{

  my ($fb, $mix, $batch);
  my @amt;

  sub batch_reset {
    $fb = FlavorBundle->new;
    $mix = Mix->new( flavor => $fb );
    $batch = Batch->new( mix => $mix );
  }

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

  sub size {
    $batch->size( first { looks_like_number $_ } @_, 10 );
  }

  sub mix { $mix }

  sub mix_generate { $mix->generate }

  sub batch { $batch }

  sub batch_generate { $batch->generate }

  sub emitter { $batch->emitter( @_ ) }

  sub list_emitters { $batch->list_emitters(1) }

  sub amt_reset { @amt = () }

  sub amt {
    push @amt, [ @_ ] if @_;
  }

  sub amt_generate {

    my $s = sum map $_->[1], @amt;
    $_->[1] /= $s for @amt;

    my %fr = ( pg => 1, vg => 0 );

    for my $f ( @amt ) {
      if ($f->[0] =~ /^nic(:?otine)?$/i) {
        my (undef, $pc, %rest) = @{ $f };
        my $nic = delete $rest{mg} // 0;
        my $mg = $nic * $pc;
        nic($mg, $nic, %rest);
        next;
      }
      if ($f->[0] =~ /^(pg|vg)$/i) {
        $fr{ uc($1) } = $f->[1];
        next;
      }
      my (undef, $pc, %rest) = @{ $f };
      %rest = ( pg => 1, %rest );
      $fr{$_} += $pc * $rest{$_} for keys %rest;
      flav(@{ $f });
    }
    fill(vg => $fr{vg} + $fr{VG}, pg => 1);
  }

  # redundant
  batch_reset();
  amt_reset();

}

1;
