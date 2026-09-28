#!/usr/bin/env bash
# pokesay - render a cowsay .cow sprite with the speech bubble to the right.
# Usage:   echo "hello" | pokesay -f /path/to/file.cow [-W bubble_width]
#          fortune | pokesay -f ~/.config/cowsay/pokemons/001_bulbasaur.cow

set -euo pipefail

cowfile=""
width=50
gap=2

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) cowfile="$2"; shift 2 ;;
        -W) width="$2";   shift 2 ;;
        -g) gap="$2";     shift 2 ;;
        -h|--help)
            echo "usage: pokesay -f <cowfile> [-W bubble_width] [-g gap]"
            exit 0
            ;;
        *)  echo "pokesay: unknown arg: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$cowfile" && -r "$cowfile" ]] || {
    echo "pokesay: -f <cowfile> required and must be readable" >&2
    exit 2
}

message=$(cat)

# Use MSYS2's own perl, not whatever is first on PATH. In the UCRT64 shell that
# is /ucrt64/bin/perl (pulled in by the cowsay package), a native Windows build
# whose console output is decoded with the legacy code page instead of UTF-8,
# so the sprite's block characters come out as mojibake like "Γûä".
perl=/usr/bin/perl

sprite_file=$(mktemp)
bubble_file=$(mktemp)
trap 'rm -f "$sprite_file" "$bubble_file"' EXIT

# Extract the sprite from the .cow file by evaluating its perl heredoc.
# Stub out cowsay's placeholders so they render as plain spaces.
"$perl" -e '
    $thoughts = " ";
    $eyes     = "oo";
    $tongue   = "  ";
    do $ARGV[0];
    print $the_cow;
' "$cowfile" > "$sprite_file"

# Render the speech bubble alone. cowsay has no "no cow" flag, so we truncate
# after the bubble's bottom border (the `---` line) to drop the default cow
# body and tail.
printf "%s\n" "$message" | cowsay -W "$width" | awk '
    { print }
    /^[[:space:]]*-+[[:space:]]*$/ { exit }
' > "$bubble_file"

# Merge sprite + bubble side-by-side, padding sprite lines to a fixed
# visible width (ANSI escapes don't count toward width).
"$perl" - "$sprite_file" "$bubble_file" "$gap" <<'PERL'
my ($sf, $bf, $gap) = @ARGV;
binmode STDOUT, ":utf8";
sub slurp {
    open my $fh, "<:encoding(UTF-8)", $_[0] or die "$_[0]: $!";
    local $/;
    <$fh>;
}
my @s = split /\n/, slurp($sf);
my @b = split /\n/, slurp($bf);

# .cow files have ~4 leading whitespace-only rows for the old thought trail
# (the lines with `$thoughts` placeholders). With the bubble beside the sprite,
# those rows are dead space — collapse runs of leading blanks down to one.
my $had_blank = 0;
while (@s) {
    (my $bare = $s[0]) =~ s/\e\[[0-9;]*m//g;
    last if $bare =~ /\S/;
    shift @s;
    $had_blank = 1;
}
unshift @s, "" if $had_blank;

my $maxw = 0;
for my $line (@s) {
    (my $bare = $line) =~ s/\e\[[0-9;]*m//g;
    $maxw = length($bare) if length($bare) > $maxw;
}
# Reset ANSI state after the sprite's last visible char on each row, then
# pad to maxw with default-colored spaces. Without the reset, sprites that
# don't end in \e[0m would leak fg/bg color into the gap and the bubble
# (e.g. pikachu's yellow tail color painting the bubble's `\` and `|`).
for my $line (@s) {
    (my $bare = $line) =~ s/\e\[[0-9;]*m//g;
    $line .= "\e[0m" . " " x ($maxw - length($bare));
}

my $rows      = @s > @b ? scalar @s : scalar @b;
my $pad_s_top = int(($rows - @s) / 2);
my $pad_b_top = int(($rows - @b) / 2);
my $blank_s   = "\e[0m" . " " x $maxw;
unshift @s, $blank_s for 1 .. $pad_s_top;
unshift @b, ""        for 1 .. $pad_b_top;
push    @s, $blank_s while @s < $rows;
push    @b, ""        while @b < $rows;

my $sep = " " x $gap;
print "$s[$_]$sep$b[$_]\n" for 0 .. $rows - 1;
PERL
