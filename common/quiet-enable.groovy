import jenkins.model.Jenkins
println "Enabling quiet mode after finishing all running jobs..."
Jenkins.instance.doQuietDown(true, 5000);


