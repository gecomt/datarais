# Skip the retry back-off waits during tests (the option only lives in the
# test process).
options(datarais.sleep_fn = function(x) invisible(NULL))
