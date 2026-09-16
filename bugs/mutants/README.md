# Mutation campaign

The campaign begins only after the baseline nightly regression is clean. Each
mutant is a one-line semantic defect applied to exactly one RTL file. Run the
unchanged regression, record the first detecting test and seed, then restore the
baseline. Escapes require analysis before adding a checker.

`manifest.yaml` is the campaign plan. A result changes from `not_run` only when
the corresponding patch and archived regression evidence exist. No detection
rate is claimed yet.
