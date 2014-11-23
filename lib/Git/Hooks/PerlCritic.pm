package Git::Hooks::PerlCritic;
use 5.010;
use strict;
use warnings;

# VERSION

use Carp;
use Module::Load 'load';
use Git::Hooks;

(my $CFG = __PACKAGE__) =~ s/.*::/githooks./msx;

sub _changed {
	my $git = shift;

	my @changed
		= grep { /\.(p[lm]|t)$/xms }
		$git->command( qw/diff --cached --name-only --diff-filter=AM/ )
		;

	return \@changed;
}

sub _set_critic {
   my ($git) = @_;
   my $pc_rc_filename = $git->get_config($CFG => 'profile');

	load 'Perl::Critic';
	load 'Perl::Critic::Violation';
	load 'Perl::Critic::Utils';

	my $pc = Perl::Critic->new('-profile' => $pc_rc_filename//q{});
	my $verbosity = $pc->config->verbose;

	# set the format to be a comment
	my $format = Perl::Critic::Utils::verbosity_to_format( $verbosity );
	Perl::Critic::Violation::set_format( "# $format" );

	return $pc;
}

sub _check_violations {
   my $git = shift;
	my $files = shift;

	my @violations;
	foreach my $file ( @{$files} ) {
		state $critic = _set_critic($git);

		@violations = $critic->critique( $file );
	}

	return \@violations;
}

PREPARE_COMMIT_MSG {
	my ( $git, $commit_msg_file ) = @_;

	my $changed    = _changed( $git );
	my $violations = _check_violations( $git, $changed );

	if ( @{$violations} ) {
		my $pcf = 'Path::Class::File'; load $pcf;
		my $file     = $pcf->new( $commit_msg_file );
		my $contents = $file->slurp;

		# a space is being prepended, suspect internal join, remove it
		( $contents .= "@$violations" ) =~ s/^\ #//xmsg;

		$file->spew( $contents );
	}
};

PRE_COMMIT {
	my $git = shift;

	my $changed    = _changed( $git );
	my $violations = _check_violations( $git, $changed );

	if ( @{$violations} ) {
		print @{$violations};
		# . operator causes the array ref to give count, otherwise it would
		# stringify
		croak '# please fix ' . @{$violations} . ' perl critic errors before committing';
	}
};

1;

# ABSTRACT: Perl Critic hooks for git

=head1 DESCRIPTION

Allows you to utilize L<Perl::Critic|Perl::Critic> via
L<git hooks|http://www.kernel.org/pub/software/scm/git/docs/githooks.html>
using the L<Git::Hooks|Git::Hooks> framework.

First setup L<git-hooks.pl|Git::Hooks/"USAGE">

Then you should choose to use only one of the available hooks.

=hook pre-commit

	ln -s git-hooks.pl .git/hooks/pre-commit
	git config --add githooks.plugin PerlCritic

This hook will prevent a commit that doesn't pass L<Perl::Critic|Perl::Critic> from being
committed.

=hook prepare-commit-msg

	ln -s git-hooks.pl .git/hooks/prepare-commit-msg
	git config --add githooks.plugin PerlCritic

This hook will simply append commented out critic warnings to the commit
message, so you may review them before committing.

=head1 CONFIGURATION AND ENVIRONMENT

Option I<profile> to define a perlcriticrc file. E.g.:

	git config --add githooks.perlcritic.profile subdir/.perlcriticrc

=head1 SEE ALSO

=over

=item L<Git::Hooks|Git::Hooks>

=item L<Perl::Critic|Perl::Critic>

=item Alternative way to use Perl::Critic with Git::Hooks package: L<Git::Hooks::CheckFile|Git::Hooks::CheckFile/"CONFIGURATION">.

=back

