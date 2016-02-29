WAT Selenium tests
------------------

QVD WAT application is tested using Selenium components. In this document we will explain how to install, build and run these tests.


Server
======

Selenium server standalone has been used in server side.

Download it from here: 

    http://www.seleniumhq.org/download/

It's a .java file, so we will need to have java installed.

    apt-get install default-jre

This server need to run the browser, so we will install firefox:

    apt-get install firefox

And if we need to install it in a server, we will install a virtual buffer enviroment for X

    apt-get install xvfb
    
To launch selenium server standalone just execute:

    java -jar selenium-server-standalone.jar
    
Additionaly you can add launching line to /etc/rc.local to start selenium server any time you start your machine.
    

Building tests
==============

To build the tests we use a firefox addon named "Selenium IDE".

Know more about it here: 

    http://www.seleniumhq.org/projects/ide/

We use PERL to build the tests but it's not available by default in Selenium IDE addon 2.9.0 (if you have later version of Selenium IDE check availability). 

If it's not available, we need to install another firefox addon: 

    Selenium IDE: Perl Formatter
    
Configuring Perl Formatter
--------------------------

Perl formatter is developed to export test cases (not test suites). Due this, each exported case adds perl libraries inclusion and server connection at the beginning of the perl script. We will talk about the perl scripts dependencies in Running tests section.

We have isolated this header part to a independent script:

	/tests/selenium/lib/connection.pl
    
And we will export the test cases without this part of code. Just the perl code referred to the test.
    
To do that, we will need to configure our Perl Formatter (Options->Options->Formats->Perl) to remove the header information to export just test code. 
    
Is recomendable make a copy of the Perl format before modify it. To do that Add a new format (I.E. Perl Simple) and fill the source with the Perl formatter source. Then delete the header content and save it.

This copy of the Perl formatter will be wich we will use to export test cases to perl format.

Exporting Test cases
--------------------

When we build a test case in Selenium IDE, we export it in two formats.

	* Addon format: Save a test case (File->Save Test Case). It can be opened later to be runned, modified, exported in other format or re-used in new test suites. We store these files at /tests/selenium/cases. 

	* Perl format (using our modified version): Export a test case to Perl format (File->Export Test Case as->Perl Simple). It exports an executable perl script. We will store the script with .pl extension and the same name of test case. We store these files at /tests/selenium/pl-cases. 
    
    For example: 

	- /tests/selenium/cases/test1
	- /tests/selenium/pl-cases/test1.pl

Exporting Test suites
---------------------

Using the exported test cases we can build a test suite with Selenium IDE. After compose desired sequence of test cases, we save it (File->Sabe Test Suite) with .suite extension.

    We store these files at /tests/selenium/suites. For example:

	- /tests/selenium/suites/suite1.suite

Generating Test suites executable
---------------------------------

We have a perl script that open a test suite file, read the referred test cases and open all of them in the specific order to compose the whole suite script.

This script is /tests/lib/buildtestsuite.pl.

The beginninig of this script will be the connection headers (/tests/lib/connection.pl content).

Example:

We have 3 test cases:

	- /tests/cases/case1
	- /tests/cases/case2
	- /tests/cases/case2
	
These tests have the correspondent perl files:

	- /tests/pl-cases/case1.pl
	- /tests/pl-cases/case2.pl
	- /tests/pl-cases/case2.pl
	
We create a suite in the Firefox addon "Selenium IDE" with these cases one after one and save as a suite:

	- /tests/suites/suite1.suite

If we execute the builder script with the suite as a parameter like:

	perl lib/buildtestsuite.pl suites/suite1.suite

We obtain the full code (including headers and connection to Selenium server retrieved from lib/connection.pl) of the needy script perl to execute test suite.

This script will be used by tests runner scripts. We will talk about it in Test suites execution.

Running tests in command line
=============================

Perl dependences
----------------

To run exported tests we need to have installed some packages:

* Perl (obiously)

    apt-get install perl
    
* WWW::Selenium library

    apt-get install cpanminus
    cpanm WWW::Selenium
    
After solve these dependencies and any other (if were necessary), we are ready to execute any test suite.

Test suites execution
---------------------
    
To execute a test suite, we execute the shell script 'runtest.sh' passing the test suite path:

    ./runtest.sh suites/suite1.suite 

This executable call the script lib/buildtestsuite.pl passing the suite file as parameter. The result is stored in a temp file and executed. 
    
With the execution, we will obtain an output similar to the following:

    ok 1 - open, /wat/
    ok 2
    ok 3 - type, name=admin_tenant, tenant1
    ok 4 - type, name=admin_user, username
    ok 5 - type, name=admin_password, password
    ok 6 - click, link=Log-in
    ok 7
    1..7

Or this kind of output in case of fail:

    ok 1 - open, /wat/
    ok 2
    ok 3 - type, name=admin_tenant, tenant1
    ok 4 - type, name=admin_user, username
    ok 5 - type, name=admin_password, password
    ok 6 - click, link=Log-in
    not ok 7 - timeout
    #   Failed test 'timeout'
    #   at testwrong.pl line 30.
    1..7
    # Looks like you failed 1 test of 7.

Running tests in Jenkins
------------------------

The Perl tests format is generated by the library Test::More which supports TAP (Test Anything Protocol)

Learn more about TAP here:

    http://c2.com/cgi/wiki?PerlTap
    
So the way to integrate the tests with Jenkins is installing and using TAP plugin

    https://wiki.jenkins-ci.org/display/JENKINS/TAP+Plugin
    
