[![Moodle CI Runner CI](https://github.com/moodlehq/moodle-ci-runner/actions/workflows/ci.yml/badge.svg)](https://github.com/moodlehq/moodle-ci-runner/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/moodlehq/moodle-ci-runner/graph/badge.svg?token=l6MRUPDhw3)](https://codecov.io/gh/moodlehq/moodle-ci-runner)

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
3. The `bash` shell (version 4.3 and up).
4. The following binaries installed (note that practically all them are part of the standard linux distributions):
  * `awk`, `grep`, `head`, `mktemp`, `pwd`, `sed`, `sha1sum`, `sort`, `tac`, `tr`, `true`, `uniq`, `uuid`, `xargs`.

You also need to set several environment variables, depending on your testing requirements:

| Variable               | Options                                                 | Default             | Notes |
| --------               | -------                                                 | -------             | ----- |
| `WORKSPACE`            | /path/to/your/workspace                                 | random              | A temporal workspace will be created using `mktemp`. |
| `CODEDIR`              | /path/to/your/code                                      | WORKSPACE/moodle.   | The location of the Moodle checkout. |
| `BUILD_ID`             | STRING (e.g. 26736)                                     | process id          | Used to create a folder and store the output from your run. Recommend using an integer. |
| `DBTYPE`               | `pgsql`, `mysqli`, `mariadb`, `oci`, `mssql`, `sqlsrv`  | `pgsql`             | The database to run. Note that `mssql` is only for PHP 5.6. |
| `PHP_VERSION`          | The PHP version                                         | `8.0`               | The PHP version to run. |
| `JOBTYPE`              | `phpunit` or `behat`                                    | `phpunit`           | Used to determine which job will be run. |
| `PHPUNIT_FILTER`       | A valid phpunit filter                                  | Optional            | A valid argument to the phpunit `--filter`. |
| `PHPUNIT_TESTSUITE`    | A valid phpunit testsuite                               | Optional            | A valid argument to the phpunit `--testsuite`. |
| `BEHAT_TAGS`           | A behat tags arg                                        | Optional            | A valid argument to the behat `--tags`. |
| `BEHAT_NAME`           | A behat name arg.                                       | Optional            | A valid argument to the behat `--name`. |
| `BROWSER`              | `firefox`, `chrome`, `browserkit`, `goutte` (deprecated)| `chrome`            | The browser to use for behat tests. |
| `BROWSER_DEBUG`        | 1                                                       | Empty               | Increase verbosity for browsers which support this |
| `BROWSER_HEADLESS`     | 1                                                       | Empty               | Run the browser in headless mode |
| `BROWSER_CHROME_ARGS`  | Comma-separated args.                                | Empty               | Use additional chrome args |
| `BROWSER_FIREFOX_ARGS` | Comma-separated args.                                | Empty               | Use additional firefox args |
| `BEHAT_PARALLEL`       | INTEGER                                                 | 3                   | For behat, the number of parallel runs to perform. |
| `BEHAT_RERUNS`         | INTEGER                                                 | 1                   | For behat, the number reruns to perform for failed runs. 0 disables reruns. |
| `BEHAT_SUITE`          | A behat suite, usually pointing to a Moodle theme       | Empty               | The theme to test with Behat. Valid options are `default` (meaning site default), and `classic` for 3.7 upwards. |
| `RUNCOUNT`             | INTEGER                                                 | 1                   | Used to perform tests in a loop. Use with caution and always with tags. |
|`MOODLE_CONFIG`         | JSON STRING                                             | Empty               | Custom Modle config to use during the execution. For example, if you want to set `$CFG->noreplyaddress = 'campus@example.com';`, the value of this variable should be `{"noreplyaddress":"campus@example.com"}`. |
| `MOBILE_VERSION`       | `latest`, `next`                                        | Empty               | The Moodle app version to use when executing behat @app tests. |
| `PLUGINSTOINSTALL`     | gitrepoplugin1\|gitfolderplugin1\|gitbranchplugin1;gitrepoplugin2\|gitfolderplugin2 | Empty | External plugins to install.<br/>The following information is needed for each plugin: gitrepo (mandatory), folder (mandatory) and branch (optional).<br/>The plugin fields should be separated by "\|" and each plugin should be separated using ";".<br/>Example: "https://github.com/moodlehq/moodle-local_mobile.git\|local/mobile\|MOODLE_37_STABLE;git@github.com:jleyva/moodle-block_configurablereports.git\|blocks/configurable_reports" |
| `PLUGINSDIR`           | /path/to/your/plugins                                   | WORKSPACE/plugins   | The location of the plugins checkout. |

Apart from the "official" (production-ready) env vars above, worth mentioning that **experimental support** for [Seleniarm](https://github.com/seleniumhq-community/docker-seleniarm) (multi-arch Selenium 4 images) has been added so, if you've an Arm64 / Aarch64 host, they can be enabled by setting this:

```
export TRY_SELENIARM=1
```

Additionally, the `SELVERSION` env variable can be used to set the selenium version, but this is currently ignored when using Chrome. If you want to force it, also set the `USE_SELVERSION` variable:

```
export USE_SELVERSION=1
export SELVERSION=120.0
```

Other options are also available, but they are not recommended.

After setting all the env. variables just run:

```
./runner/main/run.sh
```

## Internal details

### A little bit of history and justification
Over the last months of 2023 this tool had a big refactor, from the original, unique, [monolithic script, see #8ea15ae](https://github.com/moodlehq/moodle-ci-runner/tree/8ea15ae6b26e12c8b0ca4bac80da2df7b1c647a2) that was doing everything perfectly ok, to a more modular design, enabling us to:

- Add new features or dependencies easily.
- Share/reuse parts of the code over multiple job types.
- Extend the tool to support new job types (beyond the original `phpunit` and `behat` ones).
- Isolate responsibilities with a lightweight `jobs, modules and stages` approach (more details below), where every part of the execution can verify if all the dependencies are ready and be executed in an expected order.
- Testability of all the above, towards safer updates and deployments of the tool).

### Overall structure

TL:DR; in one paragraph, this tool is able to execute different jobs (phpunit, behat, ...) that are composed by multiple **modules** (docker, git, php, logs, env...), over multiple standard **stages** (config, setup, teardown...), with everything orchestrated by the **runner**.

Let's describe those concepts with a little bit more of detail and understand all the APIs that are needed towards using them.

#### Jobs

Jobs (job types) are the central piece of `moodle-ci-runner`. Everything that is executed by the runner is a job (phpunit, behat, ...). A job is in charge of defining and configuring its own env variables, also to declare which modules and in which order will be used. And then, of course, the code needed to setup (init), run and teardown (finish) the execution.

Note that it's quite interesting understanding the functions explained below, because later, you will learn that the modules API is, basically, a subset of the jobs API, nothing more and nothing less.

To achieve all the above, a job MUST define the following functions (always using the job name as prefix for them):

- **_env**: declare all the environmental variables that the job is in charge of configuring. Exclusively their very own ones, those configured by modules are made available without declaring them. Empty is allowed.<br>
See, for example, the `phpunit_env()` [implementation](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/jobtypes/phpunit/phpunit.sh). The job is going to manage the test repetitions (`RUNCOUNT`), the `--filter` option (`PHPUNIT_FILTER`) and the `--testsuite` option (`PHPUNIT_TESTSUITE`).<br>
Of course, the job execution is going to use many other env. variables (say, for example, the database to run the tests, or the repository to be tested...) but as you can see, those aren't declared here. Some module will get that responsibility.<br>
Special note about `EXITCODE`. All the job types must declare that variable. It's the one used by the **runner** de determine the outcome of a job execution.
- **_modules**: similarly to the previous function, this function is really important because it defines the modules that a given job type uses. And, more important yet, it defines the order in which they will be used.<br>
See, for example, the `phpunit_modules()` [implementation](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/jobtypes/phpunit/phpunit.sh). Most of the modules there will sound to you as typical in PHPUnit execution (we need env variables, docker and git services, a running database, various mock servers...).<br>
And, about the ordering, it's also obvious, dependencies must be observed or the job won't run. For example, we cannot instantiate the `docker-database+` container before the `docker` module has done its job, or cannot make a `docker-summary` before all the `docker-xxxx` containers have been launched.<br>
Don't worry much about the modules and dependencies for now, we'll learn more about them later.
- **_check**: this function is used to verify that all the dependencies of a job are satisfied. Usually it uses one of more of these utility functions:
  - **verify_modules**: to assert that a list of modules have been already loaded and configured before being able to run anything in the job. Note, that, for jobs, normally we pass the list of modules already declared by the job. For example, the phpunit use of this function is `verify_modules "$(phpunit_modules)`. That implies that all the modules declared in the `phpunit_modules` function (documented above) will be checked to be there.
  - **verify_env**: to assert that a list of environmental variables has been declared by somebody (the job, a module, the runner...).
  - **verify_utilities**: to assert that some utilities are available in the system. Note the that runner already checks for a number of basic requirements, but if a given job has any extra requirement, this is the place to specify that.
  - And then, how not, any custom check that you want to require. Imagine checking that a given site is up and running, or that today is Sunday, or any other thing that is a requirement for the job to be processed.<br>
  Any failing check will immediately stop the job execution process.
- **_run**: this is the main execution point of a job. Must implement all the code needed to get it executed. As simple as that, this is the job ultimate reason to exist (everything before and after it are just configuration and setup steps).<br>
See, for example, the `phpunit_run()` [implementation](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/jobtypes/phpunit/phpunit.sh). Basically, it prints some information, defines the exact (PHPUnit) command to be executed and launches it in the docker container (that some module has been in charge of create). Always setting up that `EXITCODE` that we already mentioned above.

Apart from the the mandatory functions listed above, a job also MAY define other functions to allow a safer and more controlled execution (always using the job name as prefix for them). For a job implementing all them, take a look to the [behat job](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/jobtypes/behat/behat.sh):

- **_config**: while not mandatory, if a job has environmental variables (and practically all them have) then this function will become required. It is used to configure all those env variables, their defaults, applying any logic to them.<br>
It is important to note that this function MUST NOT have any instantiation code, that's `_setup` mission.
- **_setup**: executed before the main `run` function is launched, this function is in charge of instantiating any artefact or system required. It can be anything, from creating or creating a file, to install the Moodle testing site. It's important to note that this function MUST NOT have any configuration logic, that's `_conf` mission.
- **_teardown**: to complement the `_setup`, it's possible to, also, implement this function, that will be executed once the main `_run` function has ended. It aims to cleanup temp stuff that is not needed any more, or move things to reusable caches...
- **_to\_env\_file**: the runner relies on a env file to pass all the information to the containers needing it. With this function we will define all the variables that must be added to that file (note that the `env` module is the one in charge of managing that env file.
- **_to\_summary**: similarly to the previous, but more user-oriented, with this function we will define all the information (env variables mainly) to be sent to output, in a readable format (note that the `summary` module is the one in charge of managing that output).

#### Modules

Modules are small (smaller than jobs), reusable units of work that can become part of a job. They can be as simple as defining a few environmental variables, see, for example, [the browser module](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/modules/browser/browser.sh) to really complex ones, like providing database support for any job (see the [docker-database](https://github.com/moodlehq/moodle-ci-runner/tree/main/runner/main/modules/docker-database) module).
No matter of their complexity, all them share the very same API, where everything is organised using a few functions. Note that the modules API has been already explained in the Jobs section above, and everything applies exactly the same to them, just replacing job by module.

To say it with other words, we can, basically, think about modules like **mini-jobs**, but without the `_modules` function (it cannot request other modules to be used) and without the `_run` function (main execution, only proper jobs can). Other than that, they are, basically, like jobs.

It's recommended to take a look to [various of them](https://github.com/moodlehq/moodle-ci-runner/tree/main/runner/main/modules) to go understanding how they work

To provide their functionality a module MUST implement the following functions (always using the module name as prefix for them):

- **_env:**: declare all the environmental variables that the module is in charge of configuring. Exclusively their very own ones. Empty is allowed.
- **_check**: this function is used to verify that all the dependencies of a module are satisfied. Look for the documentation above, for jobs, to know more about which aspects can be checked.

Apart from the the mandatory functions listed above, a module also MAY define other functions to allow a safer and more controlled execution (always using the module name as prefix for them). For a module implementing all them, take a look to the, simple but complete, [env module](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/modules/env/env.sh):

- **_config**: while not mandatory, if a module has environmental variables (and many have) then this function will become required. It is used to configure all those env variables, their defaults, applying any logic to them.<br>
It is important to note that this function MUST NOT have any instantiation code, that's `_setup` mission.
- **_setup**: executed before the job `run` function is launched, this function is in charge of instantiating any artefact or system required by the module. It can be anything, from creating or creating a file, to setup a database or anything else. It's important to note that this function MUST NOT have any configuration logic, that's `_conf` mission.
- **_teardown**: to complement the `_setup`, it's possible to, also, implement this function, that will be executed once the job `_run` function has ended.


#### Stages

All the stuff above are executed within some well-defined stages (that surely you've already imagined from the name of the functions).

- **env and check**: where all the environmental variables are declared and the checks executed. The exact order of affairs is:
  - declare job env variables (some modules may need them).
  - declare modules env variables (in the order defined by the job).
  - run modules checks (in the order defined by the job).
  - run job checks (after modules env and checks are completed).
- **config**: configure all the env variables with the values that will be used for the jobs execution:
  - run modules config (in the order defined by the job).
  - run job config (once all modules have setup their config).
- **setup**: instantiate everything that is going to be needed in the job execution:
  - run modules setup (in the order defined by the job).
  - run job setup (once all the modules have instantiated all the requirements).
- **run**: execute the job. Only the job has a `_run()` function.
- **teardown**: when the job ends, or there is an error, or the job is aborted, it's time to stop any instance and cleanup any temp stuff. It's executed as follows (note that the order is the inverse of the normal one):
  - run job teardown (the job goes before the modules).
  - run the modules teardown (they are executed in the inverse order they are defined by the job).

(the exact order of execution can be easily inspected in the [main run()](https://github.com/moodlehq/moodle-ci-runner/blob/main/runner/main/lib.sh) function of the runner, that is the one orchestrating everything)

#### Runner

Apart from the explanations above that cover both the jobs and the modules there are a couple of scripts worth commenting:

- **run.sh**: this is the main script of the runner. It requires only a few variables to be set (`CODEDIR`, `JOBTYPE`, ...) and, then, after a few verifications, it effectively executes the job and returns an exit status.
- **lib.sh**: where everything resides. From common/utility functions to all the stuff needed to orchestrate the jobs and modules execution.
