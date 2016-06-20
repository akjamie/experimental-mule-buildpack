# Cloud Foundry Java Buildpack for the Anypoint Platform

This extension of the [`java-buildpack`](https://github.com/cloudfoundry/java-buildpack) is a Cloud Foundry buildpack for running [Anypoint Platform](https://docs.mulesoft.com/mule-fundamentals/v/3.8/anypoint-platform-primer) applications.  It is designed to run both traditional Mule Integration applications and APIs (gateways and implementations) on both the Anypoint Runtime Engine (ESB) or API Gateway Runtime. 


## Installation

**1. Clone this github repository**

**2. Select the appropriate Mulesoft artifacts repository** 

Edit the [`config/mule.yml`](config/mule.yml) file to the repository where the buildpack will find Mulesoft artifacts:
	
* If using [Mulesoft's Nexus-2-buildpack repository proxy facility](https://anypoint.mulesoft.com/apiplatform/jesusdeoliveira/#/portals/organizations/aa30fc71-3aa1-491f-b81a-464dd9e41f2e/apis/73317/versions/76323). The Nexus-2-buildpack repository proxy is a cloud API that translates Nexus releases catalogs into JavaBuilpack versioned component dependency repositories. You'll need an API key and secret and appropriate Nexus credentials in order to use this component: 
	* Uncomment the appropriate section to use *APIGateway runtimes* or *Anypoint Runtime Engine (ESB) runtimes*. 
	* Update `version` varible according to the version of the runtime you want to make available through the buildpack. For example: 
		* if you want to enable all versions on the 3.x family, use `3.+`
		* if you want to enable all minor versions of 3.7 family, use `3.7.+`
		* If you want to enable only version 3.8.0, use `3.8.0`
		* (more information about how the JavaBuildpack versioned dependency component resolves versions and syntax of version specifications, see here: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md#version-syntax-and-ordering)
	* Replace credentials appropriately:
		* `<client_id>`: Your Mulesoft's Nexus-2-buildpack repository proxy facility API key
		* `<client_secret>`: Your Mulesoft's Nexus-2-buildpack repository proxy facility API secret
		* `<nexusUsername>`: Your Mulesoft's EE Nexus repository username
		* `<nexusPassword>`: Your Mulesoft's EE Nexus repository password

* Otherwise, if using a custom JavaBuildpack repository, update the [`config/mule.yml`](config/mule.yml) file accordingly (more information on how to set-up a custom JavaBuildpack repository can be found here: (https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md)).	


**3. Select between Oracle JDK or Open JDK**

Uncomment the appropriate entry on the [`config/components.yml`](config/components.yml) file, on the `jres` section.
	
**NOTE:** *Due to licensing restrictions, if using Oracle JDK, you need to provision a JavaBuildpack versioned component repository with the JDK distribution and reference this repository on the `repository_root` parameter of the [`config/oracle_jre`](config/oracle_jre.yml) file. Information on how to set-up a custom JavaBuildpack versioned component repository can be found here: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md.*


**4. Add your custom resources**

The `resources/mule` directory replicates the *Anypoint Runtime Engine (ESB)* or *APIGateway Runtime* directory structure. Files and directories in this location will be **overlaid** on the expanded runtime upon deployment. Typical resources to add include:

* Custom shared libraries (jar files) in `resources/mule/lib/user`
* Patches (jar files) in `resources/mule/lib/user`, `resources/mule/lib/mule` and `resources/mule/plugins`
* Custom domains in `resources/mule/domains`

Refer to [Mulesoft documentation](https://docs.mulesoft.com/mule-user-guide/v/3.7/classloader-control-in-mule) or Support Portal Knowledge Base for specific details on using custom libraries and patches.


**5. Commit your changes**


From this point, you can `cf push` applications using this builpack by referencing the git clone URL, for example: 

```
cf push -b https://github.com/myorg/mycloned-buildpack-repo myapp.zip
```


**6. Optionally, [package](https://docs.run.pivotal.io/buildpacks/custom.html) your buildpack for installation:** 
* If packaging an on-line buildpack, use for example: `bundle exec rake package`
* If packaging an off-line buildpack, use for example: `bundle exec rake package OFFLINE=true`

**7. Optionally, [install](https://docs.run.pivotal.io/buildpacks/custom.html) your buildpack on your PCF environment**

For example: `cf create-buildpack BUILDPACK_NAME BUILDPACK_ZIP_PATH POSITION`.




## Operation

### Application desing and configuration considerations

#### Inbound HTTP endpoints

When designing your applications, keep in mind that CloudFoundry will automatically allocate an internal port on the container linked to the routes defined on the CF Router for the application. This port is supplied to the application through the java property `${http.port}`. *This will be the only port your application will receive inbound traffic*. Additionally, *applications can only provide a single HTTP listener component*.

**NOTE:** If using APIGateway Runtime, the runtime provides a pre-defined shared listener already configured to use this property. Your application should reference this listener, for example:
```
<http:listener config-ref="http-lc-0.0.0.0-8081" path="/api/*" doc:name="HTTP"/>
```

#### Container disk size

Make sure you allocate more disk space than memory to your application, to be able to generate a JVM heap dump in case Mulesoft Support team requests it for diagnostics purposes. 


### Memory allocation

The Anypoint Buildpack uses the JavaBuildpack memory heuristics to allocate memory for the different JVM memory spaces, up to the maximum memory allocated to the application through configuration. 

Details about this process and the allocations can be found here: https://support.run.pivotal.io/entries/80755985-How-do-I-size-my-Java-or-JVM-based-applications-

### Application-specific configuration

Application-specific configuration is provided through Environment Variables. These can be supplied through the CloudFoundry Apps Manager application configuration, or through Manifests, as described here: https://docs.run.pivotal.io/devguide/deploy-apps/manifest.html#env-block

See an example `manifest.yml` file below:

```
---
applications:
- name: simpleapi
  buildpack: https://github.com/mulesoft-consulting/cf-java-buildpack
  env:
    ANYPOINT_PLATFORM_BASE_URI: https://anypoint.mulesoft.com/apiplatform
    ANYPOINT_PLATFORM_CORESERVICE_BASE_URI: https://anypoint.mulesoft.com/accounts
    ANYPOINT_PLATFORM_CLIENT_ID: 49d79437365517a6b96e29549744a3e1
    ANYPOINT_PLATFORM_CLIENT_SECRET: 8b037d2eea669bed28A7693418FeB297
    JBP_CONFIG_MULE: '{ offlinepolicies_root: "https://s3-eu-west-1.amazonaws.com/mule-cf-repo/userjars" }'
```


### JVM specific parameters

JVM-specific configuration parameters can be supplied through the JAVA_OPTS mechanism: either through a JAVA_OPTS [application environment variable](#application-specific-configuration), or through the [`config/java_opts`](config/java_opts) configuration file.


## Integration with other components

### Anypoint APIManager integration

***Only applies for APIGateway 2.x or ESB 3.8+.x runtimes***

APIManager integration allows you to enforce policies (traffic shaping, security and custom cross-cutting concerns) and collect analytics on your applications deployed on CloudFoundry, through the [Anypoint API Manager](https://www.mulesoft.com/platform/api/manager) component.  In order to manage an application through the APIManager, you will need to provide the following environment variables to your application:

```
ANYPOINT_PLATFORM_CLIENT_ID=<supply your anypoint org client id>
ANYPOINT_PLATFORM_CLIENT_SECRET=<supply your anypoint org client secret>
ANYPOINT_PLATFORM_BASE_URI=https://anypoint.mulesoft.com/apiplatform
ANYPOINT_PLATFORM_CORESERVICE_BASE_URI=https://anypoint.mulesoft.com/accounts
```

If using an on-premises deployment of the Anypoint Platform APIManager, edit the URLs accordingly.

Additionally, you'll need to add an *API Autodiscovery* element on your application, to link it with the corresponding API entry on the APIManager component. For example:

```
<mule ...>
	...
	<api-platform-gw:api apiName="sAPI - Clients" version="1.0" flowRef="api-main" create="true" apikitRef="api-config" doc:name="API Autodiscovery"/>
	...
</mule>
```

Find more information about API Autodiscovery here: https://docs.mulesoft.com/anypoint-platform-for-apis/api-auto-discovery

### AppDynamics integration

The Anypoint buildpack provides out-of-the-box integration with App Dynamics through the standard JavaBuildpack App Dynamics Extension. If the application has a bound custom service following [naming conventions](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/framework-app_dynamics_agent.md) and pointing to an App Dynamics instace, the JVM will start with the appropriate flags to connect to it.

See more details aboud App Dynamics integration here: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/framework-app_dynamics_agent.md


## Debugging and troubleshooting

### Debugging buildpack provisiniong process

Add a `JBP_LOG_LEVEL=debug` environment variable to generate verbose debugging output of the whole buildpack provisioning process. Debug information will be produced on the application logs.


### Patching the runtime 

Add Mulesoft patches (jar files) to the `resources/mule` directory structure as described [here](#application-specific-configuration). 

**NOTE:** *Pay special attention to the version of the runtime that patches apply to, and ensure it matches the versions the buildpack will consider as defined on the [`config/mule.yml`](config/mule.yml) file.*


### Getting diagnostics information for Mulesoft Support team

If a runtime deployed on a CF environment through the builpack runs into issues, Mulesoft Support team will request a JVM heap dump or JVM thread dump for diagnostics purposes. In order to generate one, you need to log in the CF container running your application, use JDK tools to generate the dump, and upload the data through `scp` or `sftp` outside the CF env.

**IMPORTANT:** *Make sure your application always has more disk space allocated than memory, to be able to store the dumps on the container transient storage filesystem and upload to an external SFTP or SSH server.*

To perform this process, follow these steps:

**1. Log-in your application container through SSH**

If your space configuration allows it, you can enable SSH access using the CF CLI:

```
cf enable-ssh MY-APP
```

Then you can log-in the container by doing:

```
cf ssh MY-APP
```

(If your space doesn't allow SSH access, request it to a CF administrator or deploy the app on a space that allows it)

More information on enabling SSH access can be found here: https://docs.cloudfoundry.org/devguide/deploy-apps/ssh-apps.html


**2. Find JVM process PID**

You can determine the JVM process running the Anypoint Runtime Engine or API Gateway Runtime with:

```
$ PID=$(pgrep java)
```

**3. Produce the diagnostics data**

You can use JDK toolkit to produce the diagnostics data Mulesoft Support team is requesting. 

For example, to produce a JVM heapdump with Oracle JDK use the following:
```
$ /home/vcap/app/.java-buildpack/oracle_jre/bin/jmap -dump:format=b,file=heap.bin $PID
```

To produce a JVM heapdump with Open JDK, use the following:
```
 $ /home/vcap/app/.java-buildpack/open_jdk_jre/bin/jmap -dump:format=b,file=heap.bin $PID
```

**4. Send the diagnostics data to an external SSH/SFTP server**

You can use `scp` or `sftp` to upload the dumps to an external server, from where you can provide it to Mulesoft Support team:

```
scp heap.bin user@externalserver.myorg.com:/home/user
```





