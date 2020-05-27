#!/usr/bin/env bash
set -eu

exe=${1:?First argument must be the executable to test}

root="$(cd "${0%/*}" && pwd)"
exe="$(cd "${exe%/*}" && echo "$(pwd)/${exe##*/}")"
# shellcheck disable=1090
source "$root/utilities.sh"
snapshot="$root/snapshots"

SUCCESSFULLY=0
WITH_FAILURE=1

function remove_paths() {
    sed 's_`/.*`_<redacted>_g'
}

(sandbox
  (with "with no cargo project"
    it "fails with an error message" && {
      SNAPSHOT_FILTER=remove_paths \
      WITH_SNAPSHOT="$snapshot/failure-no-cargo-manifest" \
      expect_run ${WITH_FAILURE} "$exe" diet
    }
  )
  (when "asking for help"
    it "succeeds" && {
      expect_run ${SUCCESSFULLY} "$exe" diet --help
    }
  )
)

(with "a cargo user and email"
  export CARGO_NAME=author
  export CARGO_EMAIL=author@example.com

  (sandbox
    (with "a newly initialized cargo project"
      step "init cargo project" &&
        expect_run ${SUCCESSFULLY} cargo init --name library --bin

      (with "the --dry-run flag set"
        it "runs successfully and states the crate is lean" && {
          WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project-dry-run" \
          expect_run ${SUCCESSFULLY} "$exe" diet --dry-run
        }

        it "does not modify the Cargo.toml file" && {
          expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml" "Cargo.toml"
        }
      )

      (with "NO --dry-run flag set"
        it "runs successfully and states the crate is lean" && {
          WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project" \
          expect_run ${SUCCESSFULLY} "$exe" diet
        }

        it "does not modify the Cargo.toml file" && {
          expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml" "Cargo.toml"
        }
      )

      (when "running it again" &&
        it "runs successfully" && {
          WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project" \
          expect_run ${SUCCESSFULLY} "$exe" diet
        }

        it "produces exactly the same output as before" && {
          expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml" "Cargo.toml"
        }
      )

      (with "a new test file which is part of the src/ directory"
        touch src/lib_test.rs

        (with "the -n (dry-run) flag set"
          it "runs successfully and prints diff information" && {
            WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project-test-added-dry-run" \
            expect_run ${SUCCESSFULLY} "$exe" diet -n
          }

          it "does not alter Cargo.toml" && {
            expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded-dry-run" "Cargo.toml"
          }
        )

        (with "NO --dry-run flag set"
          (when "running it again"
            it "runs successfully and states the changes" && {
              WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project-test-added" \
              expect_run ${SUCCESSFULLY} "$exe" diet
            }

            it "produces a new include directive which explicitly excludes the new file type" && {
              expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded" "Cargo.toml"
            }
          )
        )
      )
      (with "a new README file in the project root"
        touch README.md

        (when "running it" &&
          it "runs successfully" && {
            WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project" \
            expect_run ${SUCCESSFULLY} "$exe" diet
          }

          it "produces the same include as before, effectively not picking up a file it should pick up!" && {
            expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded" "Cargo.toml"
          }
        )

        (when "running it and the --reset-manifest flag is set" &&
          (with "the --dry-run flag set"
            it "runs successfully" && {
              WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project-test-added-reset-dry-run" \
              expect_run ${SUCCESSFULLY} "$exe" diet --reset-manifest --dry-run
            }

            it "produces does not alter the Cargo.toml file" && {
              expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded" "Cargo.toml"
            }
          )

          (with "NO --dry-run flag set"
            it "runs successfully" && {
              WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project-test-added-no-dryrun" \
              expect_run ${SUCCESSFULLY} "$exe" diet -r
            }

            it "produces a new include that includes the new file." && {
              expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded-and-readme" "Cargo.toml"
            }
          )
        )

        (when "running it again without --reset-manifest flag" &&
          it "runs successfully" && {
            WITH_SNAPSHOT="$snapshot/success-include-directive-in-new-project" \
            expect_run ${SUCCESSFULLY} "$exe" diet
          }

          it "produces does not alter the cargo manifest" && {
            expect_snapshot "$snapshot/success-include-directive-in-new-project-cargo-toml-with-tests-excluded-and-readme" "Cargo.toml"
          }
        )
      )
    )
  )
)
