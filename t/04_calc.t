use strict;
use warnings;

use Test::More;

use Capture::Tiny qw( capture );
use Try::Tiny;
use JSON;

use App::JuiceCalc::Simple;

my ($out, $err, $rc);

sub do_mix { my $code = shift;
  capture {
    try {
      batch_reset;
      $code->(@_);
      emitter 'Default::default_simple_json';
      size 1;
      batch_generate;
    }
    catch {
      warn $_;
    };
  };
}

#dd [ out => $out, err => $err, rc => $rc ];
#say '=' x 10;
#say for $out;
#say '=' x 10;
#say for $err;
#say '=' x 10;

( $out, $err, $rc ) = do_mix(
  sub {
      nic 20, 100, pg => 1;
      fill vg => .40, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (60/40 PG/VG)',
  flavors => [
    { name => 'VG', volume => .4, },
    { name => 'PG', volume => .4, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
  ],
}, 'minimal no flavor base mix';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      nic 20, 100, vg => 1;
      fill vg => .40, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (60/40 PG/VG)',
  flavors => [
    { name => 'PG', volume => .6, },
    { name => 'VG', volume => .2, },
    { name => '100 mg/ml Nicotine VG', volume => .2, },
  ],
}, 'minimal no flavor vg base mix';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      nic 20, 100, vg => .5, pg => .5;
      fill vg => .40, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (60/40 PG/VG)',
  flavors => [
    { name => 'PG', volume => .5, },
    { name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine 50/50 PG/VG', volume => .2, },
  ],
}, 'minimal no flavor vg base mix';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'big', .8, pg => 1;
      nic 20, 100, pg => 1;
      fill vg => .40, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (100/0 PG/VG)',
  flavors => [
    #{ name => 'PG', volume => .5, },
    #{ name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'big PG', volume => .8 },
  ],
}, 'no room for fills';

like decode_json($out)->{title}, qr/\(100\/0 PG\/VG\)/, 'title adjusted for actual ratio';
like $err, qr/^No room for adjusting ratio$/m, 'warned about fill fail';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'big', .9, pg => 1;
      nic 20, 100, pg => 1;
      fill vg => .40, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 10 mg/ml (100/0 PG/VG)',
  flavors => [
    #{ name => 'PG', volume => .5, },
    #{ name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .1, },
    { name => 'big PG', volume => .9 },
  ],
}, 'no room for nic';
like $err, qr/^Only reached \d\d\.\d\d mg \(desired: \d\d\.\d\d\)\.$/m, 'warned about less nicotine';
like $err, qr/^No room for adjusting ratio$/m, 'warned about fill fail';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'f1', .1;
      nic 20, 100, pg => 1;
      fill vg => .30, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (70/30 PG/VG)',
  flavors => [
    { name => 'PG', volume => .4, },
    { name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'f1 PG', volume => .1 },
  ],
}, 'simple pg flavor';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'f1', .1;
      flav 's1', .1, dw => 1;  # sweetener in distilled water
      nic 20, 100, pg => 1;
      fill vg => .30, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (60/30/10 PG/VG/DW)',
  flavors => [
    { name => 'PG', volume => .3, },
    { name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'f1 PG', volume => .1 },
    { name => 's1 DW', volume => .1 },
  ],
}, 'non pg/vg flavor';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'foo', .1;
      flav 'foo', .05, dw => 1;  # sweetener in distilled water
      nic 20, 100, pg => 1;
      fill vg => .30, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (65/30/5 PG/VG/DW)',
  flavors => [
    { name => 'PG', volume => .35, },
    { name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'foo PG', volume => .1 },
    { name => 'foo DW', volume => .05 },
  ],
}, 'same name flavors';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
      flav 'foo', .1;
      nic 20, 100, pg => 1;
      fill vg => .30, dw => .2, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (50/30/20 PG/VG/DW)',
  flavors => [
    { name => 'VG', volume => .3, },
    { name => 'DW', volume => .2, },
    { name => 'PG', volume => .2, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'foo PG', volume => .1 },
  ],
}, 'DW fill';
ok !$err, 'no error messages';

( $out, $err, $rc ) = do_mix(
  sub {
    amt 'foo' => 10;
    amt 'bat' =>  5;
    amt 'nic' => 20, pg => .5, vg => .5, mg => 100;
    amt 'VG' =>  30;
    amt 'PG' =>  35;
    amt_generate;
  }
);

# the amt_generate() caclulations yield long fractions,
# round them for testing ease.

use Number::Format qw( round );

my $info = decode_json($out);
for (@{ $info->{flavors} }) {
  $_->{volume} = round($_->{volume}, 2);
}

is_deeply $info,
{
  title => 'Unknown Flavor 20 mg/ml (60/40 PG/VG)',
  flavors => [
    { name => 'PG', volume => .35, },
    { name => 'VG', volume => .30, },
    { name => '100 mg/ml Nicotine 50/50 PG/VG', volume => .2, },
    { name => 'foo PG', volume => .1 },
    { name => 'bat PG', volume => .05 },
  ],
}, 'caclucate via amt()';
ok !$err, 'no error messages';


( $out, $err, $rc ) = do_mix(
  sub {
      flav 'f1', .1;
      base 100, pg => 1;
      mg 20;
      fill vg => .30, pg => 1;
  }
);

is_deeply decode_json($out),
{
  title => 'Unknown Flavor 20 mg/ml (70/30 PG/VG)',
  flavors => [
    { name => 'PG', volume => .4, },
    { name => 'VG', volume => .3, },
    { name => '100 mg/ml Nicotine PG', volume => .2, },
    { name => 'f1 PG', volume => .1 },
  ],
}, 'use base and mg instead of nic';
ok !$err, 'no error messages';

pass;
done_testing;
