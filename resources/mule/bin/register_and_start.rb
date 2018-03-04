require 'json'
require 'fileutils'
require 'open3'

#parse the VCAP APPLICATION ENV VAR SO WE HAVE THE INFO WE NEED
appData = JSON.parse(ENV['VCAP_APPLICATION'])

#read variables from environment
USER = ENV['ANYPOINT_USERNAME']
PASS = ENV['ANYPOINT_PASSWORD']
ANYPOINT = ENV['ANYPOINT_ARM_HOST']
ENVIRONMENT = ENV['ANYPOINT_ENVIRONMENT']
SERVER_NAME = "#{appData['application_name']}#{ENV['CF_INSTANCE_INDEX']}"
JAVA_HOME = ENV['JAVA_HOME']
ANYPOINT_ON_PREM = ENV['ANYPOINT_ARM_ONPREM']
JAVA_OPTS = ENV['JAVA_OPTS']
APP_ID = appData['application_id']  
INSTANCE_INDEX=ENV['CF_INSTANCE_INDEX']
  
SCRIPT_FOLDER = File.expand_path(File.dirname(__FILE__))

#utility function
def shell(*args)
	Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
		while line = stdout.gets
	    	puts line
	  	end
		if wait_thr.value != 0
		  puts "\nCommand '#{args.join ' '}' has failed"
		  puts "STDOUT: #{stdout.gets nil}"
		  puts "STDERR: #{stderr.gets nil}"

		  fail
		end
	end
end

def register
	puts "Logging into the platform..."

	json = `curl -k -s -X POST 'https://#{ANYPOINT}/accounts/login?username='#{USER}'&password='#{PASS}`

	if json.eql? "Unauthorized"
		puts "Authentication failed..."
		exit 1
	end

	#parse the response.
	json = JSON.parse(json)

	#this is the access token for the API
	access_token = json['access_token']

	#build a header for the token
	token_header = "-H \"Authorization: Bearer #{access_token}\""



	#learn which is the organization ID of the current user
	puts "Getting the current org id..."
	json = `curl -k -s -X GET #{token_header} https://#{ANYPOINT}/accounts/api/me`

	json = JSON.parse(json)

	org_id =  json['user']['organization']['id']

	#build a header for the organization id
	org_header = "-H \"X-ANYPNT-ORG-ID: #{org_id}\""

	#get the current environement id.
	puts "Getting the id for the selected environment..."
	json = `curl -k -s -X GET #{token_header} https://#{ANYPOINT}/accounts/api/organizations/#{org_id}/environments`

	json = JSON.parse(json)

	env_id = nil

	json['data'].each do |env| 
		if env['name'].eql? ENVIRONMENT
			env_id = env['id']
			break
		end
	 end

	#build a header for the environment id.
	env_header = "-H \"X-ANYPNT-ENV-ID: #{env_id}\""


	########## At this point we can check if the server exists and if it does, delete it. #######
	puts "Looking for servers with the same name..."

	json = `curl -k -s -X GET #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers`


	json = JSON.parse(json)

	json['data'].each do |srv|
	    
	    if srv['name'].eql? SERVER_NAME
	        puts "Found server with name: #{SERVER_NAME}, attempting to clear it ..."
	        `curl -k -s -X DELETE #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers/#{srv['id']}`
	        break
	    end
	end

	###### At this point we can get the registration token #######
	puts "Getting registration token..."
	json = `curl -k -s -X GET #{token_header} #{org_header} #{env_header} https://#{ANYPOINT}/hybrid/api/v1/servers/registrationToken`

	json = JSON.parse(json)

	reghash = json['data']

	#Run the server registration script...
	if ANYPOINT_ON_PREM.nil? || ANYPOINT_ON_PREM.empty?

	  cmd = [
	      "export",
	      "JAVA_HOME=#{JAVA_HOME}",
	      "&&",
	      "#{SCRIPT_FOLDER}/amc_setup",
	      "-H",
	      reghash,
	      "#{SERVER_NAME}"
	    ].flatten.compact.join(' ')
	else
	    #this is the command that needs to be used with arm on prem
	    cmd = [
	        "export",
	        "JAVA_HOME=#{JAVA_HOME}",
	        "&&",
	        "#{SCRIPT_FOLDER}/amc_setup",
	        "-A http://#{ANYPOINT}:8080/hybrid/api/v1",
	        "-W \"wss://#{ANYPOINT}:8443/mule\"",
	        "-F https://#{ANYPOINT}/apiplatform",
	        "-C https://#{ANYPOINT}/accounts",
	        "-H",
	        reghash,
	        "#{SERVER_NAME}"
	      ].flatten.compact.join(' ')
	end

	puts "Running registration..."
	puts `#{cmd}`
end


def generate_cluster_id
	
	token = 'bearer eyJhbGciOiJSUzI1NiJ9.eyJqdGkiOiI3ZTA5Zjc5ZC1iMGU2LTRjM2YtOTA0NS1lZWI1MGE1NTc0MzciLCJzdWIiOiI2NWY4OGIyZC02OTc0LTQxNjYtODJhYy02MWI4MjE2YmRhMWEiLCJzY29wZSI6WyJjbG91ZF9jb250cm9sbGVyLnJlYWQiLCJwYXNzd29yZC53cml0ZSIsImNsb3VkX2NvbnRyb2xsZXIud3JpdGUiLCJvcGVuaWQiLCJ1YWEudXNlciJdLCJjbGllbnRfaWQiOiJjZiIsImNpZCI6ImNmIiwiYXpwIjoiY2YiLCJncmFudF90eXBlIjoicGFzc3dvcmQiLCJ1c2VyX2lkIjoiNjVmODhiMmQtNjk3NC00MTY2LTgyYWMtNjFiODIxNmJkYTFhIiwib3JpZ2luIjoidWFhIiwidXNlcl9uYW1lIjoianVhbmNhdmFsbG90dGkiLCJlbWFpbCI6Imp1YW5jYXZhbGxvdHRpIiwicmV2X3NpZyI6Ijk3ODRiMWIiLCJpYXQiOjE0Njg1MzA4ODEsImV4cCI6MTQ2ODUzODA4MSwiaXNzIjoiaHR0cHM6Ly91YWEuc3lzdGVtLnBjZi5tdWxlc29mdC5jb20vb2F1dGgvdG9rZW4iLCJ6aWQiOiJ1YWEiLCJhdWQiOlsiY2xvdWRfY29udHJvbGxlciIsInBhc3N3b3JkIiwiY2YiLCJ1YWEiLCJvcGVuaWQiXX0.B0O35BJSGBBADHtDorqy8Q0ljyHat2EFoaLziC0qoXQX6yNWkdtntLEgWne9QkRc-d6J5j42Tk8lBrtDAwsRzj6r52DMVMpvj_8KKIfngUQ2iImG9cAMHhSBexDq6_53WgEXb-sHX0AIjiiD4a0qHeKFDGbBY6Icd2qSM5MnhPenJGftsgpqpsrGvSbNyg71aOYfuPkfOX3j44_zKqNyoEjRZrvl_1bPSzNpWJ42fZNNtUk_4va9tUJHGTAwToQ7WNcMFzdviQR92ren7xeEnvib18p9zsWSh8fLbkMr9irxYu9VTBgLdLedO1Rr8AxUwYmj7SkBu_F2I0UOLAEaew'

	json = `curl -k -s -X GET https://api.system.pcf.mulesoft.com/v2/apps/#{APP_ID}/stats -H \"Authorization: #{token}\" -H \"Cookie: \"`

	stats = JSON.parse(json)

	ips = []

	stats.each do |key, value|
		ips.push value['stats']['host'] 
	end

	return [
		"-M-Dmule.cluster.multicastenabled=false",
		"-M-Dmule.cluster.nodes=#{ips.flatten.compact.join(',')}",
		"-M-Dmule.clusterId=#{APP_ID}",
		"-M-Dmule.clusterNodeId=#{INSTANCE_INDEX}",
		"-Dmule.clusterSize=#{ips.length}"
	].flatten.compact.join ' '

end


def run
	################### FINALLY RUN THE MULE #####################
	
	mem = ENV['MEMORY_LIMIT'].chomp("m").to_i

	if File.file?("#{SCRIPT_FOLDER}/gateway")	
		startupScript = "gateway"
	else 
		startupScript = "mule"
	end

	cmd = [
	    "export",
	    "JAVA_HOME=#{JAVA_HOME}",
	    "&&",
		"#{SCRIPT_FOLDER}/#{startupScript}",
	    "-M-Dmule.agent.enabled=false",
	    "-M-Danypoint.platform.client_id=$ANYPOINT_PLATFORM_CLIENT_ID",
      "-M-Danypoint.platform.client_secret=$ANYPOINT_PLATFORM_CLIENT_SECRET",
      "-M-Danypoint.platform.platform_base_uri=$ANYPOINT_PLATFORM_BASE_URI",
      "-M-Danypoint.platform.coreservice_base_uri=$ANYPOINT_PLATFORM_CORESERVICE_BASE_URI",
      generate_cluster_id,
	    "-M-Dhttp.port=$PORT",
	    JAVA_OPTS.gsub('-D', '-M-D')
	 ].flatten.compact.join(' ')
	 
	puts "Running mule..."
	puts cmd
	shell cmd
end



if !ANYPOINT.nil?
	register
end

run

