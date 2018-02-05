<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = getenv('DBTYPE');
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('DBHOST');
$CFG->dbname    = getenv('DBNAME');
$CFG->dbuser    = getenv('DBUSER');
$CFG->dbpass    = getenv('DBPASS');
$CFG->prefix    = 'm_';
$CFG->dboptions = ['dbcollation' => getenv('DBCOLLATION')];

// Skip language upgrade during the on-sync period.
$CFG->skiplangupgrade = false;

$CFG->wwwroot   = 'http://host.name';
$CFG->dataroot  = '/var/www/moodledata';
$CFG->admin     = 'admin';
$CFG->directorypermissions = 0777;

// Debug options - possible to be controlled by flag in future..
$CFG->debug = (E_ALL | E_STRICT); // DEBUG_DEVELOPER
$CFG->debugdisplay = 1;
$CFG->debugstringids = 1; // Add strings=1 to url to get string ids.
$CFG->perfdebug = 15;
$CFG->debugpageinfo = 1;
$CFG->allowthemechangeonurl = 1;
$CFG->passwordpolicy = 0;

$CFG->phpunit_dataroot  = '/var/www/phpunitdata';
$CFG->phpunit_prefix = 't_';

$CFG->behat_wwwroot   = 'http://' . getenv('WEBSERVER');
$CFG->behat_dataroot  = '/var/www/behatdata';
$CFG->behat_prefix = 'b_';
$CFG->behat_profiles = [
    'default' => [
        'browser' => getenv('BROWSER'),
        'wd_host' => getenv('SELENIUMURL_0') . '/wd/hub',
    ],
];
$CFG->behat_faildump_path = '/shared';

$CFG->behat_parallel_run = [];
for ($run = 0; $run < getenv('BEHAT_TOTAL_RUNS'); $run++) {
    $CFG->behat_parallel_run[$run] = [
        'wd_host' => getenv("SELENIUMURL_{$run}"),
    ];

    // Copy the default profile for use re-runs.
    $CFG->behat_profiles["default{$run}"] = $CFG->behat_profiles['default'];
}

define('PHPUNIT_LONGTEST', true);

define('TEST_LDAPLIB_HOST_URL', 'ldap://' . getenv('LDAPTESTNAME'));
define('TEST_LDAPLIB_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_LDAPLIB_BIND_PW', 'password');
define('TEST_LDAPLIB_DOMAIN', 'ou=Users,dc=openstack,dc=org');

define('TEST_AUTH_LDAP_HOST_URL', 'ldap://' . getenv('LDAPTESTNAME'));
define('TEST_AUTH_LDAP_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_AUTH_LDAP_BIND_PW', 'password');
define('TEST_AUTH_LDAP_DOMAIN', 'ou=Users,dc=openstack,dc=org');

define('TEST_ENROL_LDAP_HOST_URL', 'ldap://' . getenv('LDAPTESTNAME'));
define('TEST_ENROL_LDAP_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_ENROL_LDAP_BIND_PW', 'password');
define('TEST_ENROL_LDAP_DOMAIN', 'ou=Users,dc=openstack,dc=org');

if (!empty(getenv('EXTTESTURL'))) {
    define('TEST_EXTERNAL_FILES_HTTP_URL', getenv('EXTTESTURL'));
}

require_once(__DIR__ . '/lib/setup.php');
