use strict;
use warnings;
use v5.10;

package App::JuiceCalc::Emitter::Extra;
use Moo;
use Carp;

our %emitters = (
  extra_template => {
    summary => 'Process a Text::Template template',
    description => <<'_',
_

  },
);

sub extra_template {
  my %args = @_;
  my $title = delete $args{title} // '';
  my $table = delete $args{table} // die "no table\n";
  my $batch = delete $args{batch} // die "no batch\n";
  my $emitter_args = delete $args{emitter_args} // {};
  my $template = delete $emitter_args->{template} // die "no template\n";
  #my $out_fh = delete $emitter_args->{out_fh} // \*STDOUT;
  my $out_fh;

  if (my $filename = delete $emitter_args->{outfile}) {
    open $out_fh, '>', $filename or die "bad outfile: $!\n";
  }
  else {
    $out_fh = delete $emitter_args->{out_fh} // \*STDOUT;
  }

  my $template_args = delete $emitter_args->{template_args} // { new => {}, fill_in => {} };

  require Text::Template;

  my $t = Text::Template->new(
    delimiters => [ '<?', '?>' ],
    source => $template,
    %{ $template_args->{new} },
  ) or croak "Problem processing $template $Text::Template::ERROR\n";

  $t->fill_in(
    output => $out_fh,
    %{ $template_args->{fill_in} },
    hash => {
      page_title => $batch->mix->flavor->name,
      title => $title,
      name => $title,
      table => $batch->mix->generate->{mix},
      amount => $batch->size,
    }
  ) or croak "Problem processing $template $Text::Template::ERROR\n";

}

1;
__END__
=pod

=encoding utf-8

=head1 NAME

App::JuiceCalc::Emitter::Extra - Extra emitters (output formatters)

=head1 VERSION

version 0.01

=head1 DESCRIPTION

=head1 INCLUDED EMITTERS

=over

=item * extra_template (Default)

Process a Text::Template template.

=back

=cut
