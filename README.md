demo
=====================

## Introduction
This demo illustrates how an application built upon a component with security flaws can leave the whole system vulnerable. It then shows how a SecurityManager can be used to add protection by limiting the scope of impact.
*Please note that this web application uses a vulnerable version of struts.*

The example vulnerability was based on information found on the following pages:
http://blog.o0o.nu/2012/01/cve-2011-3923-yet-another-struts2.html
http://www.exploit-db.com/exploits/18329/ 

## Building the Demo
Run the following command:
```
mvn clean package
```
This will generate a war file in the project `target` folder. 

## Running the Demo
The demo is as follows:
 1. Build the war file as described above.
 2. Copy the war file into the Tomcat `webapp` folder e.g. `cp target/demo-1.0-SNAPSHOT.war ~/Downloads/apache-tomcat-7.0.39/webapps/`
 3. Start Tomcat by running the following: `<TOMCAT_HOME>/bin/catalina.sh start`
 4. Navigate to the index page of the application e.g. http://localhost:8080/demo-1.0-SNAPSHOT/index.jsp
 5. Enter something simple into the form like "Robert"
 6. Enter the malicious URL http://localhost:8080/demo-1.0-SNAPSHOT/UserName.action?userName=/tmp/bad.txt&x[new+java.io.FileWriter%28userName%29]=1
 7. Look at the timestamp of the file `ls -l /tmp/bad.txt` We can see that the file has just been created/overwritten.
 8. Shutdown tomcat
 9. Start Tomcat in secure mode by running the following: `<TOMCAT_HOME>/bin/catalina.sh start -secure` - the policy file must be setup for the application in advance.
 10. Repeat steps 4-7. In this case we can see that no file has been created; instead we see a warning in `catalina.out`:

```
WARNING: Error setting expression 'x[new java.io.FileWriter(userName)]' with value '[Ljava.lang.String;@3b7447c5'
ognl.MethodFailedException: Method "new" failed for object java.io.FileWriter [java.security.AccessControlException: access denied (java.io.FilePermission /tmp/junk4.txt write)]
        at ognl.OgnlRuntime.callConstructor(OgnlRuntime.java:1405)
        at ognl.ASTCtor.getValueBody(ASTCtor.java:121)
        at ognl.SimpleNode.evaluateGetValueBody(SimpleNode.java:212)
        at ognl.SimpleNode.getValue(SimpleNode.java:258)
        ...
```

## Configuring the Policy
The policy was built by running Tomcat with the security manager and security debugging enabled. Debugging can be enabled by running the following before starting Tomcat: `export CATALINA_OPTS=-Djava.security.debug=all`
The process is iterative:
 1. Run the start Tomcat command `./catalina.sh start -security`
 2. Check `catalina.out` for errors.
 3. Add new permissions as required to the `catalina.policy` file in the conf folder, returning to 1. as permissions are added.

Once Tomcat starts cleanly with the application deployed
 1. Run each page in the application
 2. Check each page functions as expected and check the logs for errors
 3. Add new permissions as required, returning to step 1. 

Following the above process the following policy was developed for the application.  

```
grant codeBase "file:${catalina.base}/webapps/demo-1.0-SNAPSHOT/-" {
    permission java.io.FilePermission
        "${catalina.base}/-", "read";

    permission java.lang.RuntimePermission "accessClassInPackage.org.apache.catalina.loader";
    permission java.lang.RuntimePermission "accessClassInPackage.org.apache.catalina.util";
    permission java.lang.RuntimePermission "accessClassInPackage.org.apache.catalina.*";
    permission java.lang.RuntimePermission "accessDeclaredMembers";
    permission java.util.PropertyPermission "jboss.vfs.forceVfsJar", "read";
    permission java.util.PropertyPermission "xwork.saxParserFactory", "read";
    permission java.util.PropertyPermission "xwork.saxTransformerFactory", "read";
    permission java.util.PropertyPermission "java.util.logging.config.class", "read";
    permission java.util.PropertyPermission "freemarker.development", "read";
    permission java.util.PropertyPermission "freemarker.debug.password", "read";
    permission java.util.PropertyPermission "file.encoding", "read";
    permission java.util.PropertyPermission "elementAttributeLimit", "read";
    permission java.util.PropertyPermission "maxOccurLimit", "read";    
    permission java.util.PropertyPermission "xwork.profile.activate", "read";
    permission java.util.PropertyPermission "user.dir", "read";
    permission java.lang.reflect.ReflectPermission "suppressAccessChecks";
    permission ognl.OgnlInvokePermission "invoke.org.apache.struts2.components.Component.getParameters";
    permission ognl.OgnlInvokePermission "invoke.org.apache.struts2.dispatcher.StrutsResultSupport.setLocation";
    permission ognl.OgnlInvokePermission "invoke.org.apache.struts2.components.Property.setValue";
    permission ognl.OgnlInvokePermission "invoke.com.collir24.demo.UserName.setUserName";    
    permission ognl.OgnlInvokePermission "invoke.com.collir24.demo.UserName.getUserName";    
};
```

## Testing the Performance Impact of a SecurityManager
One of the reasons given for not running with a security manager is the performance impact. Having been unable to find recent studies showing the impact of enabling the security manager a simple benchmark was running using Apache Bench.  

### Configuration
The following configuration was used to test:
 * Intel MacBook Pro running 10.8.0
 * Java 1.6.0_43
 * apache-tomcat-7.0.39 with the following settings:
   * `export $CATALINA_OPTS=-Xms256m -Xmx512m`   
   * All logging in conf/logging.properties was set to ``INFO``
 * ApacheBench, Version 2.3
The version of struts2 etc. can be seen in the pom file.

### Running the test
The test was run in a number of steps
 1. Remove all files from the Tomcat logs, temp and work folders
 2. Start Tomcat with and without the security flag depending on the test
 3. Run the Apache ab command to 'warm up' the server and allow any HotSpot compilation to occur. The results from this run were discarded.
 4. Run the Apache ab command.
 5. Record the results.
  
The command run was:
```bash
ab -n 20000 -c 10 -T 'application/x-www-form-urlencoded' -p ab-post-example.txt http://localhost:8080/demo-1.0-SNAPSHOT/UserName
```

## Results
My expectation in running the benchmark was that running with a security manager enabled would reduce performance. I expected only a very minimal reduction in performance; a percentage or two. My reasoning behind this was:
 1. The number of permissions is not large; querying against a set of permissions should be very quick.
 2. The HotSpot compiler should optimize frequently executed code paths. Assuming permissions checks were being executed frequently, the path should be well optimized.

The results were not as expected, running with a security manager had a noticeable impact on performance. Without a SecurityManager we see 50% of results returned with 8ms. With a SecurityManager this figure jumps to 21ms.
It is important to note that this is very much a micro-benchmark. This demo is a simple form taking a simple parameter and is not representative of a real web application. Where an application performs a more realistic workload the overhead of running with a security manager may be less.

### Running Without a SecurityManager
```
Concurrency Level:      10
Time taken for tests:   36.743 seconds
Complete requests:      20000
Failed requests:        0
Write errors:           0
Total transferred:      7060000 bytes
Total POSTed:           3820000
HTML transferred:       1980000 bytes
Requests per second:    544.33 [#/sec] (mean)
Time per request:       18.371 [ms] (mean)
Time per request:       1.837 [ms] (mean, across all concurrent requests)
Transfer rate:          187.64 [Kbytes/sec] received
                        101.53 kb/s sent
                        289.17 kb/s total

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    4 155.0      0    7011
Processing:     2   14  16.2      8     310
Waiting:        0   13  14.4      7     150
Total:          2   18 155.8      8    7019

Percentage of the requests served within a certain time (ms)
  50%      8
  66%     15
  75%     20
  80%     24
  90%     35
  95%     46
  98%     60
  99%     72
 100%   7019 (longest request)
```

### Running With a SecurityManager   
```
Concurrency Level:      10
Time taken for tests:   48.332 seconds
Complete requests:      20000
Failed requests:        0
Write errors:           0
Total transferred:      7060000 bytes
Total POSTed:           3820000
HTML transferred:       1980000 bytes
Requests per second:    413.80 [#/sec] (mean)
Time per request:       24.166 [ms] (mean)
Time per request:       2.417 [ms] (mean, across all concurrent requests)
Transfer rate:          142.65 [Kbytes/sec] received
                        77.18 kb/s sent
                        219.83 kb/s total

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.9      0      14
Processing:     3   24  18.7     20     179
Waiting:        0   23  18.5     20     179
Total:          3   24  18.7     21     180
WARNING: The median and mean for the initial connection time are not within a normal deviation
        These results are probably not that reliable.

Percentage of the requests served within a certain time (ms)
  50%     21
  66%     29
  75%     33
  80%     37
  90%     48
  95%     59
  98%     75
  99%     86
 100%    180 (longest request)
 ```


 
