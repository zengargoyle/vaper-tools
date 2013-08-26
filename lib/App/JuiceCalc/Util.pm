package App::JuiceCalc::Util;
use Exporter::Lite;
our @EXPORT_OK = qw(
  describe_ratio
  in_epsilon
);

sub in_epsilon { abs($_[0]-$_[1]) < 1e-5 }

sub describe_ratio {
    my %p = ref $_[0] eq ref {} ? %{ $_[0] } :  @_;
    my @o = sort { $b->[1] <=> $a->[1] || $a->[0] cmp $b->[0] } map { [ $_ => $p{$_} ] } grep {$_ ne 'mg' } keys %p;
    #dd [ p => \%p, o => \@o, huh => $o[0][1] ];
    if (@o == 1) {
        if ($p{$o[0]->[0]} == 1) {
            return uc($o[0]->[0]);
        }
        die "single ratio is not 1";
    }
    join('/', map { sprintf "%.0f", $_->[1] * 100 } @o)
    . ' ' .
    join('/', map { uc $_->[0] } @o);
}

1;
