# Moodle Test Runner

This test runner was designed to be run within a CI environment to give a consistent interface for running both Behat, and PHPUnit tests for Moodle.

It can also be run locally.

## Layout

Each branch has a folder location within this repository with its own copy
of the code.

In most situations these are a symlink, but if required the script and config an be forked for a major change.

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

| Variable            | Options                                                 | Default         | Notes |
| --------            | -------                                                 | -------         | ----- |
| `WORKSPACE`         | /path/to/your/workspace                                 | EMPTY!!         | For local testing, there is a gitignore for a workspace directory in root of this repository. |
| `BUILD_ID`          | STRING (e.g. Int)                                       | EMPTY!!         | Used to create a folder and store the output from your run. Recommend using an Integer. |
| `DBTYPE`            | `pgsql`, `mysqli`, `mariadb`, `oci`, `mssql`, `sqlsrv`  | `pgsql`         | The database to run. Note that `mssql` is only for PHP 5.6. |
| `TESTTORUN`         | `phpunit` or `behat`                                    | `phpunit`       | Used to determine which test will be run. |
| `TAGS`              | A behat tag arg, or phpunit filter                      | Optional        | The tag argument to behat, or a valid argument to the phpunit `--filter`. |
| `BROWSER`           | `firefox`, `chrome`, `goutte`                           | `chrome`        | The browser to use for behat tests. |
| `BEHAT_TOTAL_RUNS`  | INTEGER                                                 | 3               | For behat, the number of parallel runs to perform. |
| `BEHAT_SUITE`       | Theme                                                   | Empty           | The theme to test with Behat. Valid options are `default` (meaning site default), `clean`, and `more`. |
| `RUNCOUNT`          | INTEGER                                                 | 1               | Used to perform tests in a loop. Use with caution and always with tags. |

Other args are also available too, but are not recommended.

After setting arguments:

```
./runner/master/run.sh
```
