set -u

# ------------------------------------------------------------
# Compare Files — Final Payload Builder + Viewer Launcher
#
# Input:
#
# $1 = JSON from the FIRST local-analysis shell script
#
# $2 = AI JSON response
#      Only present when status == AI_REQUIRED
#
# For LOCAL_RESULT:
# only $1 is required.
#
# Pass Input: as arguments
# ------------------------------------------------------------

BASE_JSON="${1-}"
AI_JSON="${2-}"

# Install per user or for all users. No account-specific path is required.
APP="$HOME/Applications/CompareFilesViewer.app"
if [[ ! -d "$APP" ]]; then
    APP="/Applications/CompareFilesViewer.app"
fi

# ------------------------------------------------------------
# Validate input
# ------------------------------------------------------------

if [[ -z "$BASE_JSON" ]]; then
    /usr/bin/osascript <<'APPLESCRIPT'
display dialog "No Compare Files local analysis result was received." with title "Compare Files" buttons {"Close"} default button "Close"
APPLESCRIPT
    exit 1
fi

# ------------------------------------------------------------
# Validate app
# ------------------------------------------------------------

if [[ ! -d "$APP" ]]; then
    /usr/bin/osascript - "$APP" <<'APPLESCRIPT'
on run argv
    display dialog "CompareFilesViewer could not be found:\n\n" & (item 1 of argv) with title "Compare Files" buttons {"Close"} default button "Close"
end run
APPLESCRIPT
    exit 1
fi

if [[ ! -x "$APP/Contents/MacOS/CompareFilesViewer" ]]; then
    /usr/bin/osascript - "$APP" <<'APPLESCRIPT'
on run argv
    display dialog "CompareFilesViewer exists, but its internal executable is invalid:\n\n" & (item 1 of argv) with title "Compare Files" buttons {"Close"} default button "Close"
end run
APPLESCRIPT
    exit 1
fi

# ------------------------------------------------------------
# Temporary files
# ------------------------------------------------------------

FINAL_JSON="$(/usr/bin/mktemp -t compare-files-viewer)" || exit 1
ERROR_FILE="$(/usr/bin/mktemp -t compare-files-error)" || {
    rm -f "$FINAL_JSON"
    exit 1
}

cleanup_error() {
    rm -f "$ERROR_FILE"
}

trap cleanup_error EXIT INT TERM HUP

# ------------------------------------------------------------
# Merge local JSON + AI analysis
# ------------------------------------------------------------

if ! /usr/bin/perl \
    -MJSON::PP \
    -MEncode \
    -e '
        use strict;
        use warnings;

        my ($base_raw, $analysis_raw, $output_path) = @ARGV;

        my $json = JSON::PP->new
            ->utf8
            ->canonical(1)
            ->pretty(1);

        # ----------------------------------------------------
        # Parse local JSON
        # ----------------------------------------------------

        my $base;

        eval {
            $base = $json->decode($base_raw);
        };

        if ($@ || ref($base) ne "HASH") {
            die "__USER_ERROR__The local analysis result is not valid JSON.";
        }

        my $status = $base->{status} // "";

        # ----------------------------------------------------
        # Local error
        # ----------------------------------------------------

        if ($status eq "ERROR") {
            my $message =
                $base->{error}
                // "An unknown error occurred during local analysis.";

            die "__USER_ERROR__$message";
        }

        # ----------------------------------------------------
        # AI result required
        # ----------------------------------------------------

        if ($status eq "AI_REQUIRED") {

            if (
                !defined($analysis_raw) ||
                $analysis_raw eq ""
            ) {
                die "__USER_ERROR__The AI analysis result is missing.";
            }

            # Tolerate accidental Markdown JSON fences.
            $analysis_raw =~ s/^\s*```(?:json)?\s*//i;
            $analysis_raw =~ s/\s*```\s*$//;

            my $analysis;

            eval {
                $analysis =
                    $json->decode($analysis_raw);
            };

            if (
                $@ ||
                ref($analysis) ne "HASH"
            ) {
                die "__USER_ERROR__The AI response is not valid JSON.";
            }

            # ------------------------------------------------
            # Required AI fields
            # ------------------------------------------------

            my @required = qw(
                overall_relation
                confidence
                main_file
                version_order
                groups
                summary
                recommendation
            );

            for my $key (@required) {
                if (!exists $analysis->{$key}) {
                    die "__USER_ERROR__AI JSON is missing the required field: $key";
                }
            }

            # ------------------------------------------------
            # Validate enums
            # ------------------------------------------------

            my %allowed_relation = map {
                $_ => 1
            } qw(
                EXACT
                NEAR_DUPLICATE
                VERSION
                SAME_PROJECT
                UNRELATED
                MIXED
                UNCERTAIN
            );

            my %allowed_group_relation = map {
                $_ => 1
            } qw(
                EXACT
                NEAR_DUPLICATE
                VERSION
                SAME_PROJECT
                UNRELATED
                UNCERTAIN
            );

            my %allowed_confidence = map {
                $_ => 1
            } qw(
                HIGH
                MEDIUM
                LOW
            );

            if (
                !$allowed_relation{
                    $analysis->{overall_relation} // ""
                }
            ) {
                die "__USER_ERROR__AI JSON contains an invalid overall_relation value.";
            }

            if (
                !$allowed_confidence{
                    $analysis->{confidence} // ""
                }
            ) {
                die "__USER_ERROR__AI JSON contains an invalid confidence value.";
            }

            # ------------------------------------------------
            # Validate array fields
            # ------------------------------------------------

            if (
                ref($analysis->{version_order})
                ne "ARRAY"
            ) {
                die "__USER_ERROR__AI JSON version_order must be an array.";
            }

            if (
                ref($analysis->{groups})
                ne "ARRAY"
            ) {
                die "__USER_ERROR__AI JSON groups must be an array.";
            }

            # ------------------------------------------------
            # Build valid filename set
            # ------------------------------------------------

            my %valid_files;

            if (
                exists($base->{files}) &&
                ref($base->{files}) eq "ARRAY"
            ) {
                for my $file (@{$base->{files}}) {
                    next unless ref($file) eq "HASH";

                    my $name = $file->{name};

                    if (
                        defined($name) &&
                        $name ne ""
                    ) {
                        $valid_files{$name} = 1;
                    }
                }
            }

            # ------------------------------------------------
            # Validate main file
            # ------------------------------------------------

            if (
                defined($analysis->{main_file}) &&
                !$valid_files{$analysis->{main_file}}
            ) {
                die "__USER_ERROR__AI JSON main_file is not one of the input files.";
            }

            # ------------------------------------------------
            # Validate version order
            # ------------------------------------------------

            for my $name (
                @{$analysis->{version_order}}
            ) {
                if (!$valid_files{$name}) {
                    die "__USER_ERROR__AI JSON version_order contains an unknown file: $name";
                }
            }

            # ------------------------------------------------
            # Validate groups
            # ------------------------------------------------

            for my $group (
                @{$analysis->{groups}}
            ) {
                if (ref($group) ne "HASH") {
                    die "__USER_ERROR__AI JSON groups contains an invalid object.";
                }

                for my $key (
                    qw(
                        files
                        relation
                        main_file
                        version_order
                        differences
                    )
                ) {
                    if (!exists $group->{$key}) {
                        die "__USER_ERROR__AI JSON group is missing the required field: $key";
                    }
                }

                if (
                    !$allowed_group_relation{
                        $group->{relation} // ""
                    }
                ) {
                    die "__USER_ERROR__AI JSON group contains an invalid relation value.";
                }

                if (
                    ref($group->{files}) ne "ARRAY" ||
                    ref($group->{version_order}) ne "ARRAY" ||
                    ref($group->{differences}) ne "ARRAY"
                ) {
                    die "__USER_ERROR__AI JSON group array fields have an invalid format.";
                }

                my %group_files;

                for my $name (
                    @{$group->{files}}
                ) {
                    if (!$valid_files{$name}) {
                        die "__USER_ERROR__AI JSON group contains an unknown file: $name";
                    }

                    $group_files{$name} = 1;
                }

                if (
                    defined($group->{main_file}) &&
                    !$group_files{$group->{main_file}}
                ) {
                    die "__USER_ERROR__AI JSON group main_file is not part of that group.";
                }

                for my $name (
                    @{$group->{version_order}}
                ) {
                    if (!$group_files{$name}) {
                        die "__USER_ERROR__AI JSON group version_order contains a file outside the group: $name";
                    }
                }
            }

            # Add AI analysis into local payload.
            $base->{analysis} = $analysis;
        }

        # ----------------------------------------------------
        # Local result already contains analysis
        # ----------------------------------------------------

        elsif ($status eq "LOCAL_RESULT") {

            if (
                !exists($base->{analysis}) ||
                ref($base->{analysis}) ne "HASH"
            ) {
                die "__USER_ERROR__The local result is missing analysis.";
            }
        }

        # ----------------------------------------------------
        # Unknown state
        # ----------------------------------------------------

        else {
            die "__USER_ERROR__Unknown Compare Files status: $status";
        }

        # ----------------------------------------------------
        # Remove fields only needed by AI
        # ----------------------------------------------------

        if (
            exists($base->{files}) &&
            ref($base->{files}) eq "ARRAY"
        ) {
            for my $file (@{$base->{files}}) {
                next unless ref($file) eq "HASH";

                delete $file->{text_excerpt};
                delete $file->{text_excerpt_truncated};
            }
        }

        if (
            exists($base->{local_evidence}) &&
            ref($base->{local_evidence}) eq "HASH"
        ) {
            # Preserve comparison-limit evidence for the viewer.
        }

        # These are workflow-only fields.
        delete $base->{schema_version};
        delete $base->{status};
        delete $base->{error};

        # ----------------------------------------------------
        # Write final viewer payload
        # ----------------------------------------------------

        open my $fh, ">:raw", $output_path
            or die "__USER_ERROR__Unable to create the final JSON file.";

        print {$fh} $json->encode($base);

        close $fh;
    ' \
    "$BASE_JSON" \
    "$AI_JSON" \
    "$FINAL_JSON" \
    2>"$ERROR_FILE"
then
    message="$(cat "$ERROR_FILE")"

    # Remove Perl line-number suffix.
    message="$(
        print -r -- "$message" \
            | sed \
                -e 's/^__USER_ERROR__//' \
                -e 's/ at -e line [0-9][0-9]*.*$//' \
                -e 's/[[:space:]]*$//'
    )"

    [[ -n "$message" ]] || \
        message="Unable to generate the Compare Files result."

    /usr/bin/osascript - "$message" <<'APPLESCRIPT'
on run argv
    set msg to item 1 of argv

    display dialog msg with title "Compare Files" buttons {"Close"} default button "Close"
end run
APPLESCRIPT

    rm -f "$FINAL_JSON"
    exit 1
fi

# ------------------------------------------------------------
# Launch installed CompareFilesViewer.app
# ------------------------------------------------------------

/usr/bin/open \
    -na "$APP" \
    --args \
    --file "$FINAL_JSON"

OPEN_STATUS=$?

if (( OPEN_STATUS != 0 )); then
    rm -f "$FINAL_JSON"

    /usr/bin/osascript <<'APPLESCRIPT'
display dialog "Unable to launch CompareFilesViewer." with title "Compare Files" buttons {"Close"} default button "Close"
APPLESCRIPT

    exit 1
fi

# ------------------------------------------------------------
# Keep payload available long enough for the app to read it.
# Remove it automatically afterwards.
# ------------------------------------------------------------

(
    /bin/sleep 60
    /bin/rm -f "$FINAL_JSON"
) >/dev/null 2>&1 &!

exit 0
