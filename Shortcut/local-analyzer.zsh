set -u

# ============================================================
# Compare Files — Local Analyzer
#
# Output ALWAYS JSON:
#
# status = ERROR
#
# status = LOCAL_RESULT
#
# status = AI_REQUIRED
#
# ============================================================


# ------------------------------------------------------------
# JSON helpers
# ------------------------------------------------------------

json_string() {
    /usr/bin/printf '%s' "${1-}" |
    /usr/bin/perl \
        -MJSON::PP \
        -MEncode \
        -0777 \
        -e '
            use strict;
            use warnings;

            binmode STDIN, ":raw";
            binmode STDOUT, ":raw";

            local $/;
            my $raw = <STDIN>;
            $raw = "" unless defined $raw;

            my $text;

            eval {
                $text = Encode::decode(
                    "UTF-8",
                    $raw,
                    Encode::FB_CROAK
                );
            };

            if ($@) {
                $text = Encode::decode(
                    "UTF-8",
                    $raw,
                    Encode::FB_DEFAULT
                );
            }

            print JSON::PP
                ->new
                ->utf8
                ->allow_nonref
                ->encode($text);
        '
}


json_nullable_string() {
    local value="${1-}"

    if [[ -n "$value" && "$value" != "(null)" ]]; then
        json_string "$value"
    else
        print -rn -- "null"
    fi
}


json_number_or_null() {
    local value="${1-}"

    if [[ "$value" == <-> ]]; then
        print -rn -- "$value"
    else
        print -rn -- "null"
    fi
}


emit_simple_error() {
    local message="${1-Unknown error}"

    print -rn -- '{"schema_version":1,"status":"ERROR","error":'
    json_string "$message"
    print -r -- '}'
}


# ------------------------------------------------------------
# Input validation
# ------------------------------------------------------------

if (( $# < 2 )); then
    emit_simple_error \
        "Please select at least 2 files in Finder before running Compare Files."
    exit 0
fi


# ------------------------------------------------------------
# Temporary workspace
# ------------------------------------------------------------

TMPBASE="${TMPDIR:-/tmp/}"
[[ "$TMPBASE" == */ ]] || TMPBASE="${TMPBASE}/"

WORKDIR_CF="$(
    /usr/bin/mktemp \
        -d \
        "${TMPBASE}CompareFiles.XXXXXX"
)" || {
    emit_simple_error \
        "Unable to create the Compare Files temporary directory."
    exit 0
}


cleanup() {
    /bin/rm -rf "$WORKDIR_CF" 2>/dev/null || true
}

trap cleanup EXIT INT TERM HUP


# ------------------------------------------------------------
# Arrays
# ------------------------------------------------------------

integer idx=0

typeset -a paths
typeset -a names
typeset -a exts
typeset -a sizes
typeset -a created
typeset -a modified
typeset -a hashes

typeset -a families
typeset -a media_info

typeset -a text_sigs
typeset -a text_files
typeset -a diff_text_files
typeset -a text_bytes

typeset -a image_indices

typeset -a image_pair_a
typeset -a image_pair_b
typeset -a image_pair_scores

integer image_pair_limit_reached=0
integer text_pair_limit_reached=0


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

lower() {
    print -r -- "$1" |
    /usr/bin/tr \
        '[:upper:]' \
        '[:lower:]'
}


normalize_family() {
    local n="$1"

    n="${n%.*}"

    print -r -- "$n" |
    /usr/bin/perl \
        -CSDA \
        -pe '
            for (1..4) {

                s/\s*\(\d+\)\s*$//;

                s/[\s._-]+(?:
                    copy|
                    duplicate|
                    backup|
                    bak|
                    new|
                    latest|
                    final(?:[-_ ]*final)?\d*|
                    rev(?:ision)?[-_ ]*\d+|
                    ver(?:sion)?[-_ ]*\d+|
                    v\d+(?:\.\d+)*|
                    副本|
                    复制|
                    备份|
                    最新版|
                    最终版|
                    定稿|
                    修订版\d*
                )\s*$//ix;

                s/[\s._-]+20\d{2}[-.]?\d{1,2}[-.]?\d{1,2}\s*$//;
            }

            s/[\s._-]+$//;
        ' |
    /usr/bin/tr \
        '[:upper:]' \
        '[:lower:]'
}


extract_text() {
    local f="$1"
    local ext="$2"
    local out="$3"

    : > "$out"

    case "$ext" in

        txt|md|markdown|csv|tsv|json|xml|html|htm|log)

            /bin/cat \
                "$f" \
                2>/dev/null \
                > "$out" \
                || true
            ;;


        rtf|rtfd|doc|docx|odt|pages)

            if [[ -x /usr/bin/textutil ]]; then

                /usr/bin/textutil \
                    -convert txt \
                    -stdout \
                    "$f" \
                    2>/dev/null \
                    > "$out" \
                    || true

            fi
            ;;


        pdf)

            /usr/bin/mdls \
                -raw \
                -name kMDItemTextContent \
                "$f" \
                2>/dev/null |
            /usr/bin/sed \
                '/^(null)$/d' \
                > "$out" \
                || true
            ;;


        pptx|ppsx)

            if [[ -x /usr/bin/unzip ]]; then

                /usr/bin/unzip \
                    -p \
                    "$f" \
                    'ppt/slides/slide*.xml' \
                    2>/dev/null |
                /usr/bin/perl \
                    -CSDA \
                    -pe '
                        s#</a:p>#\n#g;
                        s#<[^>]+># #g;
                        s/&amp;/&/g;
                        s/&lt;/</g;
                        s/&gt;/>/g;
                        s/&quot;/"/g;
                        s/&apos;/'"'"'/g;
                        s/[ \t\r]+/ /g;
                    ' \
                    > "$out" \
                    || true

            fi
            ;;


        xlsx|xlsm)

            if [[ -x /usr/bin/unzip ]]; then

                /usr/bin/unzip \
                    -p \
                    "$f" \
                    'xl/sharedStrings.xml' \
                    2>/dev/null |
                /usr/bin/perl \
                    -CSDA \
                    -pe '
                        s#</t>#\n#g;
                        s#<[^>]+># #g;
                        s/&amp;/&/g;
                        s/&lt;/</g;
                        s/&gt;/>/g;
                        s/&quot;/"/g;
                        s/&apos;/'"'"'/g;
                        s/[ \t\r]+/ /g;
                    ' \
                    > "$out" \
                    || true

            fi
            ;;


        *)

            /usr/bin/mdls \
                -raw \
                -name kMDItemTextContent \
                "$f" \
                2>/dev/null |
            /usr/bin/sed \
                '/^(null)$/d' \
                > "$out" \
                || true
            ;;
    esac
}


prepare_diff_text() {
    local input="$1"
    local output="$2"

    if [[ ! -s "$input" ]]; then
        : > "$output"
        return
    fi

    /usr/bin/perl \
        -CSDA \
        -pe '
            s/\r$//;
            s/[ \t]+$//;
        ' \
        "$input" \
        > "$output" \
        2>/dev/null \
        || true
}


truncate_diff_line() {
    /usr/bin/printf '%s' "${1-}" |
    /usr/bin/perl \
        -MEncode \
        -0777 \
        -e '
            use strict;
            use warnings;

            binmode STDIN, ":raw";
            binmode STDOUT, ":raw";

            local $/;
            my $raw = <STDIN>;
            $raw = "" unless defined $raw;

            my $text = Encode::decode(
                "UTF-8",
                $raw,
                Encode::FB_DEFAULT
            );

            $text =~ s/[ \t]+/ /g;

            if (length($text) > 400) {
                $text = substr($text, 0, 400) . "…";
            }

            print Encode::encode("UTF-8", $text);
        '
}


emit_sample_lines_json() {
    local file="$1"
    integer max_lines="${2:-6}"
    integer n=0
    integer first=1
    local line=""
    local shortened=""

    print -rn -- '['

    while IFS= read -r line || [[ -n "$line" ]]; do

        (( ++n ))

        if (( n > max_lines )); then
            break
        fi

        shortened="$(
            truncate_diff_line "$line"
        )"

        if (( ! first )); then
            print -rn -- ','
        fi

        first=0

        json_string "$shortened"

    done < "$file"

    print -rn -- ']'
}


# ------------------------------------------------------------
# Read selected files
# ------------------------------------------------------------

for f in "$@"; do

    (( ++idx ))

    paths[$idx]="$f"
    names[$idx]="${f:t}"


    if [[ ! -e "$f" ]]; then

        emit_simple_error \
            "Unable to read file: ${names[$idx]}. The file does not exist or has been moved."

        exit 0
    fi


    if [[ ! -f "$f" ]]; then

        emit_simple_error \
            "Folder comparison is not currently supported: ${names[$idx]}."

        exit 0
    fi


    # --------------------------------------------------------
    # Basic metadata
    # --------------------------------------------------------

    local_ext="${f:e}"

    exts[$idx]="$(
        lower "$local_ext"
    )"


    sizes[$idx]="$(
        /usr/bin/stat \
            -f '%z' \
            "$f" \
            2>/dev/null \
            || true
    )"


    created[$idx]="$(
        /usr/bin/mdls \
            -raw \
            -name kMDItemFSCreationDate \
            "$f" \
            2>/dev/null |
        /usr/bin/sed \
            -E \
            '
                /^(null)$/d
                s/ \+0000$//
            ' \
            || true
    )"


    modified[$idx]="$(
        /usr/bin/stat \
            -f '%Sm' \
            -t '%Y-%m-%d %H:%M:%S %z' \
            "$f" \
            2>/dev/null \
            || true
    )"


    hashes[$idx]="$(
        /usr/bin/shasum \
            -a 256 \
            "$f" \
            2>/dev/null |
        /usr/bin/awk \
            '{print $1}'
    )"


    if [[ -z "${hashes[$idx]}" ]]; then

        emit_simple_error \
            "Unable to calculate SHA-256 for file: ${names[$idx]}."

        exit 0
    fi


    families[$idx]="$(
        normalize_family \
            "${names[$idx]}"
    )"


    # --------------------------------------------------------
    # Extract text
    # --------------------------------------------------------

    tf="$WORKDIR_CF/text-$idx.txt"

    extract_text \
        "$f" \
        "${exts[$idx]}" \
        "$tf"

    text_files[$idx]="$tf"


    # --------------------------------------------------------
    # Prepare normalized text for line diff
    # --------------------------------------------------------

    dtf="$WORKDIR_CF/diff-text-$idx.txt"

    prepare_diff_text \
        "$tf" \
        "$dtf"

    diff_text_files[$idx]="$dtf"


    if [[ -s "$tf" ]]; then

        text_bytes[$idx]="$(
            /usr/bin/stat \
                -f '%z' \
                "$tf" \
                2>/dev/null \
                || print -r -- "0"
        )"


        # Complete extracted text signature.
        #
        # Whitespace is normalized, but CASE IS PRESERVED.
        # This means case changes are also detected.
        text_sigs[$idx]="$(
            /usr/bin/tr \
                -s \
                '[:space:]' \
                ' ' \
                < "$tf" |
            /usr/bin/shasum \
                -a 256 |
            /usr/bin/awk \
                '{print $1}'
        )"

    else

        text_bytes[$idx]="0"
        text_sigs[$idx]=""

    fi


    # --------------------------------------------------------
    # Media metadata
    # --------------------------------------------------------

    case "${exts[$idx]}" in

        jpg|jpeg|png|heic|heif|tif|tiff|gif|bmp|webp)

            image_indices+=("$idx")


            w="$(
                /usr/bin/sips \
                    -g pixelWidth \
                    "$f" \
                    2>/dev/null |
                /usr/bin/awk \
                    '/pixelWidth:/{print $2}'
            )"


            h="$(
                /usr/bin/sips \
                    -g pixelHeight \
                    "$f" \
                    2>/dev/null |
                /usr/bin/awk \
                    '/pixelHeight:/{print $2}'
            )"


            fmt="$(
                /usr/bin/sips \
                    -g format \
                    "$f" \
                    2>/dev/null |
                /usr/bin/awk \
                    '/format:/{print $2}'
            )"


            media_info[$idx]="Image ${w:-?}×${h:-?}, format ${fmt:-${exts[$idx]}}"
            ;;


        *)

            pages="$(
                /usr/bin/mdls \
                    -raw \
                    -name kMDItemNumberOfPages \
                    "$f" \
                    2>/dev/null |
                /usr/bin/sed \
                    '/^(null)$/d'
            )"


            ctype="$(
                /usr/bin/mdls \
                    -raw \
                    -name kMDItemContentType \
                    "$f" \
                    2>/dev/null |
                /usr/bin/sed \
                    '/^(null)$/d'
            )"


            if [[ -n "$pages" ]]; then

                media_info[$idx]="${ctype:-${exts[$idx]}}, pages ${pages}"

            else

                media_info[$idx]="${ctype:-${exts[$idx]}}"

            fi
            ;;
    esac

done


# ------------------------------------------------------------
# Exact duplicate fast path
# ------------------------------------------------------------

integer all_same=1

for (( i=2; i<=idx; i++ )); do

    if [[ "${hashes[$i]}" != "${hashes[1]}" ]]; then

        all_same=0
        break

    fi

done


# ------------------------------------------------------------
# Image similarity evidence
# ------------------------------------------------------------

if (( ! all_same && ${#image_indices[@]} >= 2 )); then

    integer pair_count=0


    for (( a=1; a<=${#image_indices[@]}; a++ )); do

        i=${image_indices[$a]}


        for (( b=a+1; b<=${#image_indices[@]}; b++ )); do

            j=${image_indices[$b]}

            (( ++pair_count ))


            if (( pair_count > 30 )); then

                image_pair_limit_reached=1
                break 2

            fi


            bmp1="$WORKDIR_CF/image-$i.bmp"
            bmp2="$WORKDIR_CF/image-$j.bmp"


            if [[ ! -f "$bmp1" ]]; then

                /usr/bin/sips \
                    -z 64 64 \
                    -s format bmp \
                    "${paths[$i]}" \
                    --out "$bmp1" \
                    >/dev/null 2>&1 \
                    || true

            fi


            if [[ ! -f "$bmp2" ]]; then

                /usr/bin/sips \
                    -z 64 64 \
                    -s format bmp \
                    "${paths[$j]}" \
                    --out "$bmp2" \
                    >/dev/null 2>&1 \
                    || true

            fi


            score=""


            if [[ -s "$bmp1" && -s "$bmp2" ]]; then

                od1="$WORKDIR_CF/od-$i.txt"
                od2="$WORKDIR_CF/od-$j.txt"


                /usr/bin/tail \
                    -c +55 \
                    "$bmp1" |
                /usr/bin/od \
                    -An \
                    -tu1 \
                    -v |
                /usr/bin/tr \
                    -s \
                    ' ' \
                    '\n' |
                /usr/bin/sed \
                    '/^$/d' \
                    > "$od1"


                /usr/bin/tail \
                    -c +55 \
                    "$bmp2" |
                /usr/bin/od \
                    -An \
                    -tu1 \
                    -v |
                /usr/bin/tr \
                    -s \
                    ' ' \
                    '\n' |
                /usr/bin/sed \
                    '/^$/d' \
                    > "$od2"


                score="$(
                    /usr/bin/paste \
                        "$od1" \
                        "$od2" |
                    /usr/bin/awk '
                        NF == 2 {

                            d = $1 - $2

                            if (d < 0)
                                d = -d

                            total += d
                            count++
                        }

                        END {

                            if (count > 0)
                                printf "%.5f", total / (count * 255)
                        }
                    '
                )"

            fi


            image_pair_a+=("$i")
            image_pair_b+=("$j")
            image_pair_scores+=("${score:-null}")

        done
    done
fi


# ------------------------------------------------------------
# Text excerpt size
# ------------------------------------------------------------

integer excerpt_limit=$(( 30000 / idx ))

if (( excerpt_limit > 5000 )); then
    excerpt_limit=5000
fi

if (( excerpt_limit < 500 )); then
    excerpt_limit=500
fi


# ------------------------------------------------------------
# JSON: files
# ------------------------------------------------------------

emit_files_json() {

    print -rn -- '['


    for (( i=1; i<=idx; i++ )); do

        if (( i > 1 )); then
            print -rn -- ','
        fi


        excerpt=""

        if [[ -s "${text_files[$i]}" ]]; then

            excerpt="$(
                /usr/bin/head \
                    -c "$excerpt_limit" \
                    "${text_files[$i]}" |
                /usr/bin/tr \
                    '\000' \
                    ' '
            )"

        fi


        integer excerpt_truncated=0

        if (( ${text_bytes[$i]:-0} > excerpt_limit )); then
            excerpt_truncated=1
        fi


        print -rn -- '{'


        print -rn -- '"id":'
        print -rn -- "$i"


        print -rn -- ',"name":'
        json_string "${names[$i]}"


        print -rn -- ',"path":'
        json_string "${paths[$i]}"


        print -rn -- ',"extension":'
        json_nullable_string "${exts[$i]}"


        print -rn -- ',"size":'
        json_number_or_null "${sizes[$i]}"


        print -rn -- ',"created":'
        json_nullable_string "${created[$i]}"


        print -rn -- ',"modified":'
        json_nullable_string "${modified[$i]}"


        print -rn -- ',"sha256":'
        json_string "${hashes[$i]}"


        print -rn -- ',"text_sha256":'
        json_nullable_string "${text_sigs[$i]}"


        print -rn -- ',"normalized_family":'
        json_nullable_string "${families[$i]}"


        print -rn -- ',"metadata":'
        json_nullable_string "${media_info[$i]}"


        print -rn -- ',"text_excerpt":'
        json_nullable_string "$excerpt"


        print -rn -- ',"text_excerpt_truncated":'

        if (( excerpt_truncated )); then
            print -rn -- 'true'
        else
            print -rn -- 'false'
        fi


        print -rn -- '}'

    done


    print -rn -- ']'
}


# ------------------------------------------------------------
# JSON: pairwise text differences
# ------------------------------------------------------------

emit_text_differences_json() {

    print -rn -- '['

    integer pair_count=0
    integer output_count=0

    text_pair_limit_reached=0


    for (( i=1; i<=idx; i++ )); do

        for (( j=i+1; j<=idx; j++ )); do

            (( ++pair_count ))


            if (( pair_count > 30 )); then

                text_pair_limit_reached=1
                break 2

            fi


            (( ++output_count ))

            if (( output_count > 1 )); then
                print -rn -- ','
            fi


            print -rn -- '{'


            print -rn -- '"file_a":'
            json_string "${names[$i]}"


            print -rn -- ',"file_b":'
            json_string "${names[$j]}"


            # ------------------------------------------------
            # Text unavailable
            # ------------------------------------------------

            if [[ -z "${text_sigs[$i]}" ||
                  -z "${text_sigs[$j]}" ]]; then

                print -rn -- ',"status":"UNAVAILABLE"'
                print -rn -- ',"hunks":null'
                print -rn -- ',"added_lines":null'
                print -rn -- ',"removed_lines":null'
                print -rn -- ',"sample_added":[]'
                print -rn -- ',"sample_removed":[]'
                print -rn -- ',"samples_truncated":false'

                print -rn -- '}'
                continue
            fi


            # ------------------------------------------------
            # Extracted text identical
            # ------------------------------------------------

            if [[ "${text_sigs[$i]}" == "${text_sigs[$j]}" ]]; then

                print -rn -- ',"status":"IDENTICAL_TEXT"'
                print -rn -- ',"hunks":0'
                print -rn -- ',"added_lines":0'
                print -rn -- ',"removed_lines":0'
                print -rn -- ',"sample_added":[]'
                print -rn -- ',"sample_removed":[]'
                print -rn -- ',"samples_truncated":false'

                print -rn -- '}'
                continue
            fi


            # ------------------------------------------------
            # Calculate complete line diff
            #
            # Direction:
            # file_a -> file_b
            #
            # + = present in file_b, absent from file_a
            # - = present in file_a, absent from file_b
            # ------------------------------------------------

            diff_file="$WORKDIR_CF/diff-$i-$j.txt"
            added_file="$WORKDIR_CF/added-$i-$j.txt"
            removed_file="$WORKDIR_CF/removed-$i-$j.txt"

            : > "$added_file"
            : > "$removed_file"


            /usr/bin/diff \
                -U 0 \
                -- \
                "${diff_text_files[$i]}" \
                "${diff_text_files[$j]}" \
                > "$diff_file" \
                2>/dev/null \
                || true


            /usr/bin/awk \
                -v added="$added_file" \
                -v removed="$removed_file" \
                '
                    /^\+\+\+ / {
                        next
                    }

                    /^--- / {
                        next
                    }

                    /^\+/ {
                        print substr($0, 2) >> added
                        next
                    }

                    /^-/ {
                        print substr($0, 2) >> removed
                        next
                    }
                ' \
                "$diff_file"


            added_count="$(
                /usr/bin/wc \
                    -l \
                    < "$added_file" |
                /usr/bin/tr \
                    -d \
                    ' '
            )"


            removed_count="$(
                /usr/bin/wc \
                    -l \
                    < "$removed_file" |
                /usr/bin/tr \
                    -d \
                    ' '
            )"


            hunk_count="$(
                /usr/bin/grep \
                    -c \
                    '^@@' \
                    "$diff_file" \
                    2>/dev/null \
                    || true
            )"

            [[ -n "$hunk_count" ]] || hunk_count=0


            integer samples_truncated=0

            if (( ${added_count:-0} > 6 ||
                  ${removed_count:-0} > 6 )); then

                samples_truncated=1

            fi


            print -rn -- ',"status":"DIFFERENT_TEXT"'


            print -rn -- ',"hunks":'
            print -rn -- "${hunk_count:-0}"


            print -rn -- ',"added_lines":'
            print -rn -- "${added_count:-0}"


            print -rn -- ',"removed_lines":'
            print -rn -- "${removed_count:-0}"


            print -rn -- ',"sample_added":'
            emit_sample_lines_json \
                "$added_file" \
                6


            print -rn -- ',"sample_removed":'
            emit_sample_lines_json \
                "$removed_file" \
                6


            print -rn -- ',"samples_truncated":'

            if (( samples_truncated )); then
                print -rn -- 'true'
            else
                print -rn -- 'false'
            fi


            print -rn -- '}'

        done
    done


    print -rn -- ']'
}


# ------------------------------------------------------------
# JSON: local evidence
# ------------------------------------------------------------

emit_local_evidence_json() {

    print -rn -- '{'


    # --------------------------------------------------------
    # Relation signals
    # --------------------------------------------------------

    print -rn -- '"relation_signals":['

    integer signal_count=0


    for (( i=1; i<=idx; i++ )); do

        for (( j=i+1; j<=idx; j++ )); do

            typeset -a flags
            flags=()


            if [[ "${hashes[$i]}" == "${hashes[$j]}" ]]; then

                flags+=("EXACT_SHA_MATCH")

            fi


            if [[ -n "${text_sigs[$i]}" &&
                  -n "${text_sigs[$j]}" ]]; then

                if [[ "${text_sigs[$i]}" == "${text_sigs[$j]}" ]]; then

                    flags+=("EXTRACTED_TEXT_MATCH")

                else

                    flags+=("EXTRACTED_TEXT_DIFFERS")

                fi

            fi


            if [[ -n "${families[$i]}" &&
                  "${families[$i]}" == "${families[$j]}" ]]; then

                flags+=("NORMALIZED_NAME_MATCH")

            fi


            if (( ${#flags[@]} > 0 )); then

                (( ++signal_count ))


                if (( signal_count > 1 )); then
                    print -rn -- ','
                fi


                signal="${names[$i]} ↔ ${names[$j]} : ${(j:, :)flags}"

                json_string "$signal"

            fi

        done
    done


    print -rn -- ']'


    # --------------------------------------------------------
    # Complete extracted-text differences
    # --------------------------------------------------------

    print -rn -- ',"text_differences":'

    emit_text_differences_json


    print -rn -- ',"text_pair_limit_reached":'

    if (( text_pair_limit_reached )); then
        print -rn -- 'true'
    else
        print -rn -- 'false'
    fi


    # --------------------------------------------------------
    # Image differences
    # --------------------------------------------------------

    print -rn -- ',"image_differences":['

    integer image_result_count=${#image_pair_a[@]}


    for (( p=1; p<=image_result_count; p++ )); do

        if (( p > 1 )); then
            print -rn -- ','
        fi


        i=${image_pair_a[$p]}
        j=${image_pair_b[$p]}
        score="${image_pair_scores[$p]}"


        print -rn -- '{'


        print -rn -- '"file_a":'
        json_string "${names[$i]}"


        print -rn -- ',"file_b":'
        json_string "${names[$j]}"


        print -rn -- ',"score":'

        if [[ "$score" == "null" || -z "$score" ]]; then

            print -rn -- 'null'

        else

            print -rn -- "$score"

        fi


        print -rn -- '}'

    done


    print -rn -- ']'


    print -rn -- ',"image_pair_limit_reached":'

    if (( image_pair_limit_reached )); then
        print -rn -- 'true'
    else
        print -rn -- 'false'
    fi


    print -rn -- '}'
}


# ------------------------------------------------------------
# Local EXACT analysis
# ------------------------------------------------------------

emit_exact_analysis() {

    print -rn -- '{'


    print -rn -- '"overall_relation":"EXACT"'
    print -rn -- ',"confidence":"HIGH"'
    print -rn -- ',"main_file":null'
    print -rn -- ',"version_order":[]'


    print -rn -- ',"groups":['
    print -rn -- '{'


    print -rn -- '"files":['


    for (( i=1; i<=idx; i++ )); do

        if (( i > 1 )); then
            print -rn -- ','
        fi

        json_string "${names[$i]}"

    done


    print -rn -- ']'


    print -rn -- ',"relation":"EXACT"'
    print -rn -- ',"main_file":null'
    print -rn -- ',"version_order":[]'


    print -rn -- ',"differences":['

    json_string \
        "SHA-256 values are identical; the files are byte-for-byte identical."

    print -rn -- ']'


    print -rn -- '}'
    print -rn -- ']'


    print -rn -- ',"summary":'

    json_string \
        "The selected files have identical SHA-256 hashes and are byte-for-byte duplicates."


    print -rn -- ',"recommendation":'

    json_string \
        "Please manually choose which copy to keep based on the filename, location, or your preferred organization method."


    print -rn -- '}'
}


# ------------------------------------------------------------
# Final output
# ------------------------------------------------------------

if (( all_same )); then
    STATUS="LOCAL_RESULT"
else
    STATUS="AI_REQUIRED"
fi


OUTPUT_FILE="$WORKDIR_CF/result.json"


{
    print -rn -- '{'


    print -rn -- '"schema_version":1'


    print -rn -- ',"status":'
    json_string "$STATUS"


    print -rn -- ',"files":'
    emit_files_json


    print -rn -- ',"local_evidence":'
    emit_local_evidence_json


    print -rn -- ',"analysis":'

    if (( all_same )); then

        emit_exact_analysis

    else

        print -rn -- 'null'

    fi


    print -r -- '}'

} > "$OUTPUT_FILE"


# ------------------------------------------------------------
# Validate JSON using JSON::PP
# ------------------------------------------------------------

if ! /usr/bin/perl \
    -MJSON::PP \
    -0777 \
    -e '
        use strict;
        use warnings;

        binmode STDIN, ":raw";

        local $/;
        my $raw = <STDIN>;

        if (!defined($raw) || $raw eq "") {
            exit 1;
        }

        eval {
            JSON::PP
                ->new
                ->utf8
                ->decode($raw);
        };

        exit($@ ? 1 : 0);
    ' \
    < "$OUTPUT_FILE"
then

    emit_simple_error \
        "The Compare Files local analysis produced invalid JSON."

    exit 0
fi


# ------------------------------------------------------------
# ONLY normal stdout
# ------------------------------------------------------------

/bin/cat "$OUTPUT_FILE"

exit 0
