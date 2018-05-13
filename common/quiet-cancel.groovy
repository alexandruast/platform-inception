import jenkins.model.Jenkins
println "Exiting out of quiet mode..."
Jenkins.instance.doCancelQuietDown();


