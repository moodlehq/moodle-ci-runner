# Moodle Test Runner

This test runner was designed to be run within a CI environment to give a consistent interface for running both Behat, and PHPUnit tests for Moodle.

It can also be run locally.

## Layout

Each branch has a folder location within this repository with its own copy
of the code.

In most situations these are a symlink, but if required the script and config can be forked for a major change.

## Running locally

In order to run tests on your own machines, you need the following:

1. A checkout of Moodle that you intend to test. This should be checked out to a directory called `moodle` within a workspace directory.
2. The Docker engine installed and available as your current user
3. The `bash` shell
4. The following binaries installed:
  * `uuid`
  * `sha1sum`
  * `awk`
  * `grep`

You also need to set several environment variables, depending on your testing requirements:

| Variable            | Options                                                 | Default             | Notes |
| --------            | -------                                                 | -------             | ----- |
| `WORKSPACE`         | /path/to/your/workspace                                 | EMPTY!!             | For local testing, there is a gitignore for a workspace directory in root of this repository. |
| `CODEDIR`           | /path/to/your/code                                      | $WORKSPACE/moodle   | The location of the Moodle checkout. |
| `BUILD_ID`          | STRING (e.g. Int)                                       | EMPTY!!             | Used to create a folder and store the output from your run. Recommend using an Integer. |
| `DBTYPE`            | `pgsql`, `mysqli`, `mariadb`, `oci`, `mssql`, `sqlsrv`  | `pgsql`             | The database to run. Note that `mssql` is only for PHP 5.6. |
| `PHP_VERSION`       | The PHP version                                         | `7.1`               | The PHP version to run. |
| `TESTTORUN`         | `phpunit` or `behat`                                    | `phpunit`           | Used to determine which test will be run. |
| `TAGS`              | A behat tag arg, or phpunit filter                      | Optional            | The tag argument to behat, or a valid argument to the phpunit `--filter`. |
| `NAME`              | A behat name arg. Ignored for phpunit                   | Optional            | The name argument to behat. It will be ignored for phpunit. |
| `BROWSER`           | `firefox`, `chrome`, `goutte`                           | `chrome`            | The browser to use for behat tests. |
| `BROWSER_DEBUG`     | 1                                                       | Empty               | Increase verbosity for browsers which support this |
| `BROWSER_HEADLESS`  | 1                                                       | Empty               | Run the browser in headless mode |
| `BEHAT_TOTAL_RUNS`  | INTEGER                                                 | 3                   | For behat, the number of parallel runs to perform. |
| `BEHAT_NUM_RERUNS`  | INTEGER                                                 | 1                   | For behat, the number reruns to perform for failed runs. 0 disables reruns. |
| `BEHAT_SUITE`       | Theme                                                   | Empty               | The theme to test with Behat. Valid options are `default` (meaning site default), `clean` and `more` for 3.6 downwards and `classic` for 3.7 upwards. |
| `RUNCOUNT`          | INTEGER                                                 | 1                   | Used to perform tests in a loop. Use with caution and always with tags. |
| `MOBILE_VERSION`    | `latest`, `next`                                        | Empty               | The Moodle app version to use when executing behat @app tests. |
| `PLUGINSTOINSTALL`  | gitrepoplugin1\|gitfolderplugin1\|gitbranchplugin1;gitrepoplugin2\|gitfolderplugin2         | Empty               | External plugins to install.<br/>The following information is needed for each plugin: gitrepo (mandatory), folder (mandatory) and branch (optional).<br/>The plugin fields should be separated by "\|" and each plugin should be separated using ";".<br/>Example: "https://github.com/moodlehq/moodle-local_mobile.git\|local/mobile\|MOODLE_37_STABLE;git@github.com:jleyva/moodle-block_configurablereports.git\|blocks/configurable_reports" |
| `PLUGINSDIR`        | /path/to/your/plugins                                   | $WORKSPACE/plugins  | The location of the plugins checkout. |
| `MOODLE_CONFIG`     | JSON STRING                                             | Empty               | Custom moodle config to use during the execution. For example, if you want to set `$CFG->noreplyaddress = 'campus@example.com';`, the value of this variable should be `{"noreplyaddress":"campus@example.com"}`. |

Other args are also available too, but are not recommended.

After setting arguments:

```
./runner/master/run.sh
```
