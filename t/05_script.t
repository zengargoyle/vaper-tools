use strict;
use warnings;

use Test::More;
use Capture::Tiny qw( capture );
use File::Slurp;

my $output = <<'_END';
.-----------------------------------------------.
|      Fuzzy Custard 13 mg/ml (70/30 PG/VG)     |
+--------------------------------+------+-------+
| Flavor                         |   ml | Total |
+--------------------------------+------+-------+
| PG                             | 4.65 |  4.65 |
+--------------------------------+------+-------+
| VG                             | 2.35 |  7.00 |
+--------------------------------+------+-------+
| 100 mg/ml Nicotine 50/50 PG/VG | 1.30 |  8.30 |
+--------------------------------+------+-------+
| Vanilla Custard (TFA) PG       | 1.30 |  9.60 |
+--------------------------------+------+-------+
| Juicy Peach (TFA) PG           | 0.30 |  9.90 |
+--------------------------------+------+-------+
| Butterscotch (TFA) PG          | 0.10 | 10.00 |
'--------------------------------+------+-------'
_END

my ($out, $err, $rc);

($out, $err, $rc) = capture {
  system(q[./bin/quickmix n Fuzzy\ Custard f 'Vanilla Custard (TFA)' 13 f 'Juicy Peach (TFA)' 3 f 'Butterscotch (tfa)' 1 pg 1 nic 13 100 pg 50 vg 50 r vg 30 pg 100 s 10]);
};
is $out, $output, 'quickmix';

($out, $err, $rc) = capture {
  system(q[./bin/quickmix n 'Fuzzy Custard' f 'Vanilla Custard (TFA)' .13 f 'Juicy Peach (TFA)' .03 f 'Butterscotch (tfa)' .01 pg 1 nic 13 100 pg .5 vg .5 r vg .3 pg 1 s 10]);
};
is $out, $output, 'quickmix fractional';

($out, $err, $rc) = capture {
  system(q[./bin/jcalc -f t/test_data/fuzzy_custard.flav -b t/test_data/juice_talk_13.base]);
};
is $out, $output, 'jcalc';

($out, $err, $rc) = capture {
  system(q[./bin/ejmu -f 't/test_data/Fuzzy Custard.rec']);
};
is $out, $output, 'ejmu';

my $ejmu = read_file 't/test_data/Fuzzy Custard.rec';
($out, $err, $rc) = capture {
  system(q[./bin/ejmu -f 't/test_data/Fuzzy Custard.rec' --emitter=Default::default_ejmu]);
};
is $out, $ejmu, 'ejmu round trip';

done_testing;
