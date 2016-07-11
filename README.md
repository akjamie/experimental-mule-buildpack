# Cloud Foundry Java Buildpack for the Anypoint Platform

## Table of contents

  * [Introduction](#introduction)
  * [Installation](#installation)
  * [Operation](#operation)
    + [Application desing and configuration considerations](#application-desing-and-configuration-considerations)
      - [Inbound HTTP endpoints](#inbound-http-endpoints)
      - [Container disk size](#container-disk-size)
    + [Application deployment](#application-deployment)
      - [Application-specific configuration](#application-specific-configuration)
      - [Deploying behind a proxy](#deploying-behind-a-proxy)
      - [Memory allocation](#memory-allocation)
      - [JVM-specific parameters](#jvm-specific-parameters)
      - [Selecting a specific version of the runtime for an application](#selecting-a-specific-version-of-the-runtime-for-an-application)
    + [Applying patches to the Anypoint Runtime Engine](#applying-patches-to-the-anypoint-runtime-engine)
  * [Integration with third-party components](#integration-with-third-party-components)
    + [Anypoint API Manager integration](#anypoint-api-manager-integration)
    + [Integration with Anypoint Runtime Manager](#integration-with-anypoint-runtime-manager)
    + [AppDynamics integration](#appdynamics-integration)
    + [Integration with other components supported by the Java Buildpack](#integration-with-other-components-supported-by-the-java-buildpack)
  * [Debugging and troubleshooting](#debugging-and-troubleshooting)
    + [Buildpack diagnostics information](#buildpack-diagnostics-information)
    + [Debugging buildpack provisioning process](#debugging-buildpack-provisioning-process)
    + [JVM diagnostics information](#jvm-diagnostics-information)
  * [Providing diagnostics information for Mulesoft Support Team](#providing-diagnostics-information-for-mulesoft-support-team)

## Introduction

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
		* *more information about how the JavaBuildpack versioned dependency component resolves versions and syntax of version specifications, see [here](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md#version-syntax-and-ordering).*
	* Replace credentials appropriately:
		* `<client_id>`: Your Mulesoft's Nexus-2-buildpack repository proxy facility API key
		* `<client_secret>`: Your Mulesoft's Nexus-2-buildpack repository proxy facility API secret
		* `<nexusUsername>`: Your Mulesoft's EE Nexus repository username
		* `<nexusPassword>`: Your Mulesoft's EE Nexus repository password

* Otherwise, if using a custom JavaBuildpack repository, update the [`config/mule.yml`](config/mule.yml) file accordingly (more information on how to set-up a custom JavaBuildpack repository can be found here: (https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md)).	


**3. Select between Oracle JDK or Open JDK**

The Anypoint Platform buildpack uses by default OpenJDK JRE. If you prefer to use Oracle JDK, please amend the appropriate entry on the [`config/components.yml`](config/components.yml) file, on the `jres` section.
	
**NOTE:** *Due to licensing restrictions, if using Oracle JDK, you need to provision a JavaBuildpack versioned-component repository with the JDK distribution, and reference this repository on the `repository_root` parameter of the [`config/oracle_jre`](config/oracle_jre.yml) file. Information on how to set-up a custom JavaBuildpack versioned component repository can be found [here](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md).*

**4. Add a runtime license digest**

Generate a runtime license digest using [MuleSoft License Verifier service](https://mulelicenseverifier.cloudhub.io/) on your web browser: 

* Upload your MuleSoft Runtime license `.lic` file, obtained through the Customer Onboarding process, and click `Verify` button.
* Download the digested license by clicking the `Download digested license` link and placing the generated `muleLicenseKey.lic` file in `resources/mule/conf` directory.

**5. Add additional resources**

The `resources/mule` directory replicates the *Anypoint Runtime Engine (ESB)* or *APIGateway Runtime* directory structure. Files and directories in this location will be **overlaid** on the expanded runtime upon deployment. Typical resources to add include:

* Custom shared libraries (jar files) in `resources/mule/lib/user`
* Patches (jar files) in `resources/mule/lib/user`, `resources/mule/lib/mule` and `resources/mule/plugins`
* Custom domains in `resources/mule/domains`

Create the required directories as necessary. Refer to [Mulesoft documentation](https://docs.mulesoft.com/mule-user-guide/v/3.7/classloader-control-in-mule) or Support Portal Knowledge Base for specific details on using custom libraries and patches.


**6. Commit your changes**

Commit the above configuration changes, if any, to your local repository in order to keep track of changes. Feel free to use git branches to keep track of different teams or LoB specific customisations.

From this point, you can `cf push` applications using this builpack by referencing your git clone URL, for example: 

```
cf push -b https://github.com/myorg/mycloned-buildpack-repo myapp.zip
```


**7. Optionally, [package](https://docs.run.pivotal.io/buildpacks/custom.html) your buildpack for installation:** 

* If packaging an **online** buildpack, on the root of the git repo, execute `bundle exec rake package`.
* If packaging an **offline** buildpack, on the root of the git repo, execute `bundle exec rake package OFFLINE=true`,

The package script will produce a zip file on the `build` directory, named `cf-mule-buildpack-<commit hash>.zip` or `cf-mule-buildpack-offline-<commit hash>.zip` if using the offline flag.

**NOTE:** *Observe that offline buildpacks can ONLY contain a SINGLE version of the Anypoint or APIGatweay Runtime Engine, the latest available on the configured repository described on step 2 above. Refer to [CloudFoundry Java buildpack](https://github.com/cloudfoundry/java-buildpack#offline-package) for more information.*


**8. Optionally, [install](https://docs.run.pivotal.io/buildpacks/custom.html) your buildpack on your PCF environment**

Install the buildpack on your PCF environment/space by executing:

`cf create-buildpack <BUILDPACK_NAME> <BUILDPACK_ZIP_PATH> <POSITION>`.

For example:

`cf create-buildpack anypoint-buildpack-3.8 build/cf-mule-buildpack-offline-a5587b4.zip 1`.



## Operation

### Application desing and configuration considerations

#### Inbound HTTP endpoints

When designing your applications, keep in mind that CloudFoundry will automatically allocate an internal port on the container linked to the routes defined on the CF Router for the application. This port is supplied to the application through the java property `${http.port}`. *This will be the only port on which your application will receive inbound traffic*. Additionally, *applications can only provide a single HTTP listener component*.

**NOTE:** If using APIGateway Runtime Engine, the runtime provides a pre-defined shared listener already configured to use this property, called `http-lc-0.0.0.0-8081`. Your application should reference this listener, for example:
```xml
  <flow ...> 
	<http:listener config-ref="http-lc-0.0.0.0-8081" path="/api/*" doc:name="HTTP"/>
	...
  </flow>
```

**NOTE:** *Make sure your application DOES NOT provide the `http.port` variable on the `mule-app.properties` file, or configuration files loaded through Spring Properties Placeholders, as this overrides the port supplied through CloudFoundry environment variables mechanims, preventing connectivity to your app once deployed.* 

#### Container disk size

Make sure you allocate more disk space than memory to your application, to be able to generate a JVM heap dump in case Mulesoft Support team requests it for diagnostics purposes. 

### Application deployment 

#### Application-specific configuration

Application-specific configuration is provided through Environment Variables. These can be supplied through the CloudFoundry Apps Manager user interface, or through [Application manifests files](https://docs.run.pivotal.io/devguide/deploy-apps/manifest.html#env-block).

See a *minimal* example `manifest.yml` file below:

```
---
applications:
- name: simpleapi
  buildpack: https://github.com/mulesoft-consulting/cf-java-buildpack
  env:
    MYCUSTOM_ENV_VARIABLE: -mycustomflag=1234
```

#### Deploying behind a proxy 

If your CloudFoundry environment sits behind a proxy, and you are using an **online** buildpack, you'll need to supply proxy details to your app through the manifest file as described [here](https://docs.cloudfoundry.org/buildpacks/proxy-usage.html).

See an example `manifest.yml` file for this scenario below:
```
---
applications:
- name: simpleapi
  buildpack: https://github.com/mulesoft-consulting/cf-java-buildpack
  env:
    GIT_SSL_NO_VERIFY: true
    HTTP_PROXY: http://myusername:mypassword@proxy.myorg.com:80
    HTTPS_PROXY: http://myusername:mypassword@proxy.myorg.com:80
    NO_PROXY: host1.donotneedproxy.myorg.com, host2.donotneedproxy.myorg.com
```


#### Memory allocation

The Anypoint Buildpack uses the JavaBuildpack memory heuristics to allocate memory for the different JVM memory spaces, up to the maximum memory allocated to the application through configuration. 

Details about this process and the estimated proportions can be found [here](https://support.run.pivotal.io/entries/80755985-How-do-I-size-my-Java-or-JVM-based-applications-).

#### JVM-specific parameters

JVM-specific configuration parameters can be supplied through the `JAVA_OPTS` mechanism, either through:

* a `JAVA_OPTS` [application environment variable](#application-specific-configuration), 
* the [`config/java_opts`](config/java_opts) configuration file.


#### Selecting a specific version of the runtime for an application 

If you need to specify a particular version of the *Anypoint Runtime Engine* or the *Anypoint API Gateway Engine* for your application, and you are using an **online* buildpack, you can request it through the application manifest file or the CloudFoundry Apps Manager user interface, by supplying a `JBP_CONFIG_MULE` environment variable as below:

```
JBP_CONFIG_MULE={ version: <version number>, repository_root: "https://<client_id>:<client_secret>@pcf-buildpack-nexus-proxy.cloudhub.io/api/https/<nexusUsername>/<nexusPassword>/repository.mulesoft.org/443/releases-ee/com.mulesoft.muleesb.distributions/mule-ee-distribution-standalone" }
```

Replace the parameters as described on Step 2 [here](#Installation). More information about overriding components configuration options can be found [here](https://github.com/cloudfoundry/java-buildpack#configuration-and-extension).

See an example manifest file below, for an application that will use *Anypoint Runtime Engine* version `3.8.0`:

```
---
applications:
- name: simpleapi
  buildpack: https://github.com/mulesoft-consulting/cf-java-buildpack
  env:
    JBP_CONFIG_MULE: { version: 3.8.0, repository_root: "https://430838984830283942:9384g1h9178219dgh213@pcf-buildpack-nexus-proxy.cloudhub.io/api/https/nexususer/dyen384yd/repository.mulesoft.org/443/releases-ee/com.mulesoft.muleesb.distributions/mule-ee-distribution-standalone" }
```


### Applying patches to the Anypoint Runtime Engine

Add Mulesoft patches (jar files) to the `resources/mule` directory structure as described [here](#application-specific-configuration). 

**NOTE:** *Pay special attention to the version of the runtime that patches apply to, and ensure it matches the versions the buildpack will consider as defined on the [`config/mule.yml`](config/mule.yml) file.*


## Integration with third-party components

### Anypoint API Manager integration

***Only applies for APIGateway 2.x or ESB 3.8.+ runtimes***

The *Anypoint API Manager* integration allows you to enforce policies (traffic shaping, security and custom cross-cutting concerns) and collect analytics on your applications deployed on CloudFoundry, through the [Anypoint API Manager](https://www.mulesoft.com/platform/api/manager) component.  

In order to manage an application through the APIManager, you will need to provide the following environment variables to your applicationas, as described on section (#Application-specific-configuration):

	ANYPOINT_PLATFORM_CLIENT_ID=<supply your anypoint org client id>
	ANYPOINT_PLATFORM_CLIENT_SECRET=<supply your anypoint org client secret>
	ANYPOINT_PLATFORM_BASE_URI: <base services URL of your APIManager instance>
	ANYPOINT_PLATFORM_CORESERVICE_BASE_URI: <core services URL of your APIManager instance>

For example, if using the cloud-based version of *Anypoint API Manager*, an application `manifest.yml` file will look like this:

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
```

Observe that these environment variables can be combined with Anypoint Runtime Manager variables if both components are to be used.

Additionally, you'll need to add an *API Autodiscovery* element on your application, to link it with the corresponding API entry on the APIManager component. For example:

```xml
<mule ...>
	...
	<api-platform-gw:api apiName="sAPI - Clients" version="1.0" flowRef="api-main" create="true" apikitRef="api-config" doc:name="API Autodiscovery"/>
	...
</mule>
```

Find more information about API Autodiscovery [here](https://docs.mulesoft.com/anypoint-platform-for-apis/api-auto-discovery).



### Integration with Anypoint Runtime Manager ###

To manage and control an application or API through the [Anypoint Runtime Manager](https://docs.mulesoft.com/runtime-manager/) component, add the following environment variables to your app as described on section (#Application-specific-configuration):

	ANYPOINT_ARM_HOST: <hostname of your Anypoint Runtime Manager instance>
	ANYPOINT_ARM_ONPREM: true #remove this to use MuleSoft cloud-based version of ARM
	ANYPOINT_USERNAME: <Anypoint Runtime Manager username with runtime registration privileges>
	ANYPOINT_PASSWORD: <Anypoint Runtime Manager user password>
	ANYPOINT_ENVIRONMENT: <Anypoint Runtime Manager environment>

For example, if using the cloud-based version of *Anypoint Runtime Manager*, an application `manifest.yml` file will look like this:

```
---
applications:
- name: simpleapi
  buildpack: https://github.com/mulesoft-consulting/cf-java-buildpack
  env:
    ANYPOINT_USERNAME: mythicaluser
    ANYPOINT_PASSWORD: !123mySecurePassword123$
    ANYPOINT_ENVIRONMENT: Production
```
Observe that these environment variables can be combined with Anypoint API Manager variables if both components are to be used.


### AppDynamics integration

The Anypoint buildpack provides out-of-the-box integration with App Dynamics through the standard JavaBuildpack App Dynamics Extension. If the application has a bound custom service following [naming conventions](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/framework-app_dynamics_agent.md) and pointing to an App Dynamics instace, the JVM will start with the appropriate flags to connect to it.

See more details aboud App Dynamics integration here: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/framework-app_dynamics_agent.md

### Integration with other components supported by the Java Buildpack 

Other components/agents that are originally supported by the official [`java-buildpack`](https://github.com/cloudfoundry/java-buildpack) can be enabled through the (config/components.yml) file, uncommenting entries as appropriate. Although these components/agents should use the Java Buildpack standard extension mechanisms to provide required flags to the JVM, bear in mind that these components are not tested nor supported by MuleSoft.

## Debugging and troubleshooting

### Buildpack diagnostics information 

Run the following command on the buildpack clone repository root to produce diagnostics information of buildpack version and updated files:

```
$ ./cf-mule-buildpack-info
```

The output of this command will look like this:

```

Anypoint Platform buildpack diagnostics information
===================================================
Generated on the Mon 11 Jul 2016 17:05:57 BST

Remotes:
origin	https://github.com/mulesoft-consulting/cf-mule-buildpack (fetch)
origin	https://github.com/mulesoft-consulting/cf-mule-buildpack (push)

Latest commit from upstream (origin/master branch)
* 1607833 (origin/master, origin/HEAD) Initial documentation for June 2016 release.

Local customisations:
 100.0% config/
```

This provides useful information about the version of the buildpack being used, the origin upstream repository where it was "cloned" from, and verifies that local customisations are on supported places.



### Debugging buildpack provisioning process

Add a `JBP_LOG_LEVEL=debug` environment variable to generate verbose debugging output of the whole buildpack provisioning process, as described on section (#Application-specific-configuration). Debug information will be produced on the application logs.


### JVM diagnostics information 

If a runtime deployed on a CloudFoundry environment through the builpack runs into issues, Mulesoft Support team will request a JVM heap dump or JVM thread dump for diagnostics purposes. In order to generate one, you need to log in the CF container running your application, use JDK tools to generate the dump, and upload the data through `scp` or `sftp` outside the CF env.

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

For example, to produce a JVM **heap dump** with **Oracle JDK** use the following:
```
$ /home/vcap/app/.java-buildpack/oracle_jre/bin/jmap -dump:format=b,file=heap.bin $PID
```

To produce a JVM **heap dump** with **Open JDK**, use the following:
```
 $ /home/vcap/app/.java-buildpack/open_jdk_jre/bin/jmap -dump:format=b,file=heap.bin $PID
```

For example, to produce a **JVM thread dump** with **Oracle JDK** use the following:
```
$ /home/vcap/app/.java-buildpack/oracle_jre/bin/jstack -dump:format=b,file=heap.bin $PID
```

To produce a JVM **thread dump** with **Open JDK**, use the following:
```
 $ /home/vcap/app/.java-buildpack/open_jdk_jre/bin/jstack -dump:format=b,file=heap.bin $PID
```



**4. Send the diagnostics data to an external SSH/SFTP server**

You can use `scp` or `sftp` to upload the dumps to an external server, from where you can provide it to Mulesoft Support team:

```
scp heap.bin user@externalserver.myorg.com:/home/user
```


## Providing diagnostics information for Mulesoft Support Team

If you need to report an issue with the Anypoint Runtime Engine or the buildpack itself through MuleSoft support process, you'll be required to provide the following information:

* Supply [Buildpack versioning and diagnostics information](#Buildpack-diagnostics-information).
* If the issue is related to the Anypoint Runtime Engine, supply [JVM diagnostics information](#JVM-diagnostics-information).
* If the issue is related to the buildpack provisioning process, supply [application provisioning logs](#Debugging-buildpack-provisioning-process).

