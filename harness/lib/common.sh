# Shared shell helpers for the harness. Source, don't execute:
#   source "$HARNESS_DIR/lib/common.sh"
# Expects HARNESS_DIR to point at harness/.

TE_REGISTRY="${HARNESS_DIR}/lib/registry.mjs"

te_die() { echo "ERROR: $*" >&2; exit 1; }
te_note() { echo "==> $*"; }

# te_resolve_study [study-slug] — exports STUDY_SLUG, RESULTS_DIR, PERF_DIR,
# STUDY_FRAMEWORKS, SPEC_DIR, BASELINE_TAG. Falls back to the STUDY env var.
te_resolve_study() {
  local slug="${1:-${STUDY:-}}"
  if [ -z "$slug" ]; then
    te_die "no study selected — pass one or set STUDY=<slug>
  studies: $(node "$TE_REGISTRY" list-studies | tr '\n' ' ')"
  fi
  local sh
  sh="$(node "$TE_REGISTRY" sh-study "$slug")" || exit 1
  eval "$sh"
}

te_repo() { node "$TE_REGISTRY" repo "$1"; }

# te_locate_app <framework> <repo-path> [debug|release] — echoes the built .app path.
# Both the trial runner and the perf suite resolve build products through here, so
# a framework's product layout is described in exactly one place.
te_locate_app() {
  local fw="$1" repo="$2" cfgname="${3:-debug}" locator kind app=""
  locator="$(node "$TE_REGISTRY" app-locator "$fw" "$cfgname")"
  [ "$locator" = "null" ] && return 1
  kind="$(node -e 'const l=JSON.parse(process.argv[1]||"null"); process.stdout.write(l?.kind ?? "")' "$locator")"
  case "$kind" in
    glob)
      local pattern
      pattern="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).pattern)' "$locator")"
      app="$(ls -d "$repo"/$pattern 2>/dev/null | head -1)"
      ;;
    xcodebuild)
      local products
      local -a args=()
      while IFS= read -r -d '' a; do args+=("$a"); done \
        < <(node -e 'JSON.parse(process.argv[1]).args.forEach(a => process.stdout.write(a + "\0"))' "$locator")
      products="$(cd "$repo" && xcodebuild "${args[@]}" -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')"
      app="$(ls -d "$products"/*.app 2>/dev/null | head -1)"
      ;;
    *) return 1 ;;
  esac
  [ -n "$app" ] && [ -d "$app" ] || return 1
  echo "$app"
}
