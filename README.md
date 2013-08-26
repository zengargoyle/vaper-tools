vaper-tools
===========

        One of the miseries of life is that everybody names
        things a little bit wrong.
                                     -- Richard P. Feynman

[![Build Status](https://travis-ci.org/zengargoyle/vaper-tools.png)](https://travis-ci.org/zengargoyle/vaper-tools)

Documentation coming soon.

INSTALLATION
============

Get the code.

~~~~
git clone https://github.com/zengargoyle/vaper-tools.git
# or
curl -LO https://github.com/zengargoyle/vaper-tools/archive/master.zip
unzip master.zip

# then

cd vaper-tools
~~~~

For those familiar with Perl and installing modules and such...  It's
recommended to just install the prerequisites (and not App::JuiceCalc
itself, at least not yet).

~~~~
perl Build.PL

# if you're curious or want to try and find some of the prerequisite
# modules in your distribution's package management tool...
./Build prereq_report

./Build installdeps

# then test with
prove -v -Ilib t
# or
./Build test
~~~~

If you want to keep all the prerequisite modules (if any) in one place,
the best way is probably with `cpanm`.

If you don't have `cpanm` installed. (See: [cpanminus](https://github.com/miyagawa/cpanminus) for more detail.)

~~~~
curl -LO http://xrl.us/cpanm
chmod +x cpanm
# edit shebang if you don't have /usr/bin/env
~~~~

Then install the prerequisites under the './local' directory.

~~~~
cpanm --quiet --notest --local-lib local --installdeps .
# then test with
PERL5LIB=local/lib/perl5 prove -v -Ilib t
~~~~

You should now be able to use the tools in the `bin` directory.  You may want
to add it to your PATH: `PATH=$PATH:$PWD/bin` or make links to your `~/bin` or
`/usr/local/bin` as desired...  `ln -s $PWD/bin/* ~/bin`.

COMING SOON
===========

Example recipes, A walk-through of common usage, etc.  You may actually
find these things in a doc directory by now.  Otherwise see `t/05_script.t` for some test examples.

The `--help` option of the programs should help a bit.

~~~~
jcalc -f t/test_data/fuzzy_custard.flav -s 10
.-----------------------------------------.
|   Fuzzy Custard 18 mg/ml (70/30 PG/VG)  |
+--------------------------+------+-------+
| Flavor                   |   ml | Total |
+--------------------------+------+-------+
| PG                       | 3.50 |  3.50 |
+--------------------------+------+-------+
| VG                       | 3.00 |  6.50 |
+--------------------------+------+-------+
| 100 mg/ml Nicotine PG    | 1.80 |  8.30 |
+--------------------------+------+-------+
| Vanilla Custard (TFA) PG | 1.30 |  9.60 |
+--------------------------+------+-------+
| Juicy Peach (TFA) PG     | 0.30 |  9.90 |
+--------------------------+------+-------+
| Butterscotch (TFA) PG    | 0.10 | 10.00 |
'--------------------------+------+-------'
~~~~

